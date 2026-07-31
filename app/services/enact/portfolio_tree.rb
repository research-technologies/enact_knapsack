# frozen_string_literal: true

module Enact
  # A Portfolio's composition tree, read from `member_ids_ssim`. This is
  # containment; Enact::RelationshipGraph reads the curated cross-links on the
  # `relationships` compound. Issue #95.
  class PortfolioTree
    # status: nil for a plain tree; the deposit done-screen tree stamps saved
    # works `existing` and the just-deposited one `new`.
    Node = Struct.new(:id, :label, :type, :type_label, :path, :status, :children, keyword_init: true) do
      def count
        children.size
      end

      def children?
        children.any?
      end
    end

    # Backstops against a mis-modelled or cyclic hierarchy running away.
    MAX_DEPTH = 12
    MAX_NODES = 500

    # A node needs only these fields; fetching full docs for every member is the
    # bulk of the render cost for large portfolios.
    FIELDS = 'id,has_model_ssim,title_tesim,human_readable_type_tesim,member_ids_ssim'

    # Badge keys match enact/portfolio_tree.scss.
    TYPE_META = {
      'Portfolio' => %w[portfolio Portfolio],
      'PortfolioArtefact' => %w[artefact Artefact],
      'PortfolioEvent' => %w[event Event],
      'PortfolioLiterature' => %w[literature Literature],
      'PortfolioItemCollection' => %w[collection Collection]
    }.freeze

    # Only these types contain other works. Leaf items just hold their FileSets,
    # so descending into them would cost a Solr query per item and surface
    # FileSets as tree nodes.
    CONTAINER_MODELS = %w[Portfolio PortfolioItemCollection].freeze
    WORK_MODELS = TYPE_META.keys.freeze

    def initialize(ability:, max_depth: MAX_DEPTH, max_nodes: MAX_NODES)
      @ability = ability
      @max_depth = max_depth
      @max_nodes = max_nodes
      @visited = Set.new
      @node_count = 0
    end

    def for_work(id)
      # Reset so a reused instance doesn't carry stale traversal state.
      @visited = Set.new
      @node_count = 0
      doc = document_for(id)
      doc && build(doc, 0)
    end

    # nil unless a parent was chosen: only the "add to an existing work" path has
    # a hierarchy to show.
    def for_completed_deposit(parent_id:, work_id:)
      root = for_work(parent_id)
      return nil if root.nil?

      stamp(root, 'existing')
      mark_new(root, work_id.to_s)
      root
    end

    private

    def build(doc, depth)
      @node_count += 1
      @visited << doc['id'].to_s
      node_for(doc, child_nodes(doc, depth))
    end

    def child_nodes(doc, depth)
      return [] if depth >= @max_depth
      return [] unless CONTAINER_MODELS.include?(model_of(doc))

      nodes = []
      member_documents(doc).each do |child|
        break if @node_count >= @max_nodes
        next if @visited.include?(child['id'].to_s) # membership cycle

        nodes << build(child, depth + 1)
      end
      nodes
    end

    def model_of(doc)
      Array(doc['has_model_ssim']).first.to_s
    end

    def node_for(doc, children)
      model = model_of(doc)
      key, label = TYPE_META.fetch(model) { [model.underscore.presence || 'work', human_type(doc, model)] }
      # Pass the doc so path_for classifies it in-memory rather than re-querying per node.
      Node.new(id: doc['id'], label: title_of(doc), type: key, type_label: label,
               path: Hyrax::CompoundWorkResolver.path_for(doc['id'], doc:), status: nil, children:)
    end

    def stamp(node, status)
      node.status = status
      node.children.each { |child| stamp(child, status) }
    end

    def mark_new(node, work_id)
      if node.id.to_s == work_id
        node.status = 'new'
        return true
      end

      node.children.any? { |child| mark_new(child, work_id) }
    end

    def member_documents(doc)
      ids = Array(doc['member_ids_ssim']).first(@max_nodes)
      return [] if ids.empty?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => ids }, join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: ids.length, fl: FIELDS)
                             .select { |child| WORK_MODELS.include?(model_of(child)) }
    end

    def document_for(id)
      return nil if id.blank?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => id.to_s })
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: 1, fl: FIELDS).first
    end

    def title_of(doc)
      Array(doc['title_tesim']).first.presence || '(untitled)'
    end

    def human_type(doc, model)
      Array(doc['human_readable_type_tesim']).first.presence || model.titleize
    end
  end
end
