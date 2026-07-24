# frozen_string_literal: true

module Enact
  # The structural composition tree of a Portfolio, read from `member_ids_ssim`.
  # Distinct from Enact::RelationshipGraph, which reads the curated cross-links on
  # the `relationships` compound - this is containment, not citation. Issue #95.
  class PortfolioTree
    # `status` is nil for a plain tree; the deposit review tree stamps saved works
    # `existing` and the pending item `new`.
    Node = Struct.new(:id, :label, :type, :type_label, :path, :status, :children, keyword_init: true) do
      def count
        children.size
      end

      def children?
        children.any?
      end
    end

    # Caps so a mis-modelled or malicious hierarchy cannot run the recursion away.
    MAX_DEPTH = 12
    MAX_NODES = 500

    # has_model => [badge key, human label]; badge keys match enact/portfolio_tree.scss.
    TYPE_META = {
      'Portfolio' => %w[portfolio Portfolio],
      'PortfolioArtefact' => %w[artefact Artefact],
      'PortfolioEvent' => %w[event Event],
      'PortfolioLiterature' => %w[literature Literature],
      'PortfolioItemCollection' => %w[collection Collection]
    }.freeze

    def initialize(ability:, max_depth: MAX_DEPTH, max_nodes: MAX_NODES)
      @ability = ability
      @max_depth = max_depth
      @max_nodes = max_nodes
      @visited = Set.new
      @node_count = 0
    end

    # nil when the work is not found or not readable by the current ability.
    def for_work(id)
      # Reset per call so a reused instance doesn't carry stale traversal state.
      @visited = Set.new
      @node_count = 0
      doc = document_for(id)
      doc && build(doc, 0)
    end

    # The target Portfolio and its members stamped `existing`, plus the item being
    # deposited appended as a `new` leaf. nil unless a parent was chosen - only the
    # "add to an existing work" path has a hierarchy to show. `pending` is a
    # { label:, type: } hash for the not-yet-saved work.
    def for_deposit(parent_id:, pending:)
      root = for_work(parent_id)
      return nil if root.nil?

      stamp(root, 'existing')
      root.children << pending_node(pending)
      root
    end

    private

    def build(doc, depth)
      @node_count += 1
      @visited << doc['id'].to_s
      node_for(doc, child_nodes(doc, depth))
    end

    def child_nodes(doc, depth)
      return [] if depth >= @max_depth || @node_count >= @max_nodes

      member_documents(doc).filter_map do |child|
        # A member pointing back up the tree would otherwise recurse forever.
        next if @visited.include?(child['id'].to_s)

        build(child, depth + 1)
      end
    end

    def node_for(doc, children)
      model = Array(doc['has_model_ssim']).first.to_s
      key, label = TYPE_META.fetch(model) { [model.underscore.presence || 'work', human_type(doc, model)] }
      Node.new(id: doc['id'], label: title_of(doc), type: key, type_label: label,
               path: work_path(model, doc['id']), status: nil, children:)
    end

    def pending_node(pending)
      model = pending[:type].to_s
      key, label = TYPE_META.fetch(model) { [model.underscore.presence || 'work', model.titleize.presence || 'Item'] }
      Node.new(id: nil, label: pending[:label].presence || '(untitled)', type: key,
               type_label: label, path: nil, status: 'new', children: [])
    end

    def stamp(node, status)
      node.status = status
      node.children.each { |child| stamp(child, status) }
    end

    def member_documents(doc)
      ids = Array(doc['member_ids_ssim']).first(@max_nodes)
      return [] if ids.empty?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => ids }, join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: ids.length)
    end

    def document_for(id)
      return nil if id.blank?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => id.to_s })
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: 1).first
    end

    def title_of(doc)
      Array(doc['title_tesim']).first.presence || '(untitled)'
    end

    def human_type(doc, model)
      Array(doc['human_readable_type_tesim']).first.presence || model.titleize
    end

    def work_path(model, id)
      model.present? ? "/concern/#{model.tableize}/#{id}" : "/#{id}"
    end
  end
end
