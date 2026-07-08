# frozen_string_literal: true

module Enact
  # The contributor collaboration network, for the standalone "research network"
  # people map (app/views/enact/people_map/show.html.erb).
  #
  # Nodes are contributors (people and organisations, {Enact::Contributor}),
  # coloured by institution (their first affiliation, via {Palette}). Two
  # contributors are linked when they are credited on the same work; the edge
  # weight is how many works they share. This is the mirror of
  # {Enact::RelationshipGraph} (the work-to-work map): same single source of
  # truth (the works' `contributors` compound), read through a Solr reverse
  # lookup and scoped to the viewer's ability, so the network only draws works
  # the viewer may see.
  #
  # Only linked contributors (an entry's `contributor` member resolves to an
  # {Enact::Contributor}) become nodes; a free-text-only credit has no stable
  # identity to anchor a node or a profile link, so it is skipped.
  #
  # Knapsack-local custom code (Enact:: conventions, top-level namespace).
  class PeopleGraph
    # Backstop on works pulled into one network. A project corpus is small; this
    # mirrors {Enact::RelationshipMapController::MAX_WORKS} and is surfaced
    # (truncated?) rather than silently trimming.
    MAX_WORKS = 1_000

    Result = Struct.new(:institutions, :nodes, :links, :works_total, :truncated, keyword_init: true) do
      # The JSON shape the people-map JS reads from its data island; mirrors the
      # prototype so the client stays unchanged.
      def as_json(*)
        { institutions:, nodes:, links:, works_total:, truncated: }
      end
    end

    # @param ability [Ability] the viewer's abilities; the network is scoped to
    #   works this ability can :read.
    def initialize(ability:)
      @ability = ability
    end

    # @return [Result] institutions (legend), nodes (contributors), links
    #   (shared-work edges), and the works count the network was built from.
    def call
      docs = work_documents
      credits = credits_by_work(docs) # id => { title:, contributor_ids: [], roles: {id => Set} }
      @contributors = load_contributors(credits)
      @palette = Palette.new(@contributors.values.map { |c| Palette.key_for(c.affiliations.first) })

      nodes = build_nodes(credits)
      links = build_links(credits)
      Result.new(institutions: @palette.legend, nodes:, links:,
                 works_total: credits.count { |_id, c| c[:contributor_ids].any? { |cid| @contributors.key?(cid) } },
                 truncated: docs.length >= MAX_WORKS)
    end

    private

    # Accessible work docs across the registered work types (same scoping as the
    # relationship map). Capped; the cap is reported, not silent.
    def work_documents
      models = Hyrax.config.registered_curation_concern_types.presence
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'has_model_ssim' => models }, join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: MAX_WORKS)
    end

    # work_id => { title:, contributor_ids: [ids as strings], roles: {id => Set<label>} }.
    # Only entries whose `contributor` member resolves to an id are kept. Roles
    # are collected here (one walk of the entries) as human labels: controlled
    # CRediT codes via ContributorRolesService, plus free-text role_other.
    def credits_by_work(docs)
      docs.each_with_object({}) do |doc, acc|
        ids = []
        roles = Hash.new { |h, k| h[k] = Set.new }
        contributor_entries(doc).each do |entry|
          id = entry['contributor'].presence&.to_s
          next if id.blank?

          ids << id
          role_labels(entry).each { |label| roles[id] << label }
        end
        acc[doc.id.to_s] = { title: Array(doc['title_tesim']).first.to_s, contributor_ids: ids.uniq, roles: }
      end
    end

    # Controlled + free-text roles on one credit entry, as display labels.
    def role_labels(entry)
      controlled = Array(entry['role']).filter_map { |code| Enact::ContributorRolesService.label(code.to_s).presence }
      controlled + Array(entry['role_other']).filter_map { |r| r.to_s.presence }
    end

    # Load every credited contributor in one query, keyed by id string. Ids from
    # the compound are strings; the AR primary key is an integer, so key on the
    # stringified id.
    def load_contributors(credits)
      ids = credits.values.flat_map { |c| c[:contributor_ids] }.uniq
      return {} if ids.empty?

      Enact::Contributor.where(id: ids).index_by { |c| c.id.to_s }
    end

    # One node per loaded contributor. `works` is how many in-scope works credit
    # them; degree/size are computed client-side from the links.
    def build_nodes(credits)
      work_counts = Hash.new(0)
      roles_by_id = Hash.new { |h, k| h[k] = Set.new }
      credits.each_value do |c|
        c[:contributor_ids].each { |id| work_counts[id] += 1 if @contributors.key?(id) }
        c[:roles].each { |id, labels| roles_by_id[id].merge(labels) if @contributors.key?(id) }
      end

      @contributors.map { |id, contributor| node_for(id, contributor, work_counts[id], roles_by_id[id]) }
    end

    def node_for(id, contributor, works, roles)
      affiliation = contributor.affiliations.first
      key = Palette.key_for(affiliation)
      { id:, label: contributor.display_name, agent_type: contributor.agent_type,
        orcid: contributor.orcid.presence, inst: key, instLabel: Palette.label_for(affiliation),
        instColor: @palette.color(key), roles: roles.to_a.sort, works:, path: "/contributors/#{id}" }
    end

    # Undirected co-credit edges. For each work, every pair of its (loaded)
    # contributors shares an edge; the weight counts shared works and `works`
    # lists their titles. Pairs are keyed order-independently so A-B and B-A
    # accumulate together.
    def build_links(credits)
      edges = {}
      credits.each_value do |c|
        present = c[:contributor_ids].select { |id| @contributors.key?(id) }
        present.combination(2).each do |a, b|
          key = [a, b].sort
          edge = (edges[key] ||= { source: key[0], target: key[1], weight: 0, works: [] })
          edge[:weight] += 1
          edge[:works] << c[:title] if c[:title].present?
        end
      end
      edges.values
    end

    # Parse a doc's `contributors` compound into entry hashes. A SolrDocument
    # exposes a per-instance `contributors` reader (define_compound_readers!);
    # the raw-blob branch is the fallback for a bare SolrService hit. Keys are
    # strings either way. (Same reader as {Enact::ContributorGraph}.)
    def contributor_entries(doc)
      return Array(doc.contributors) if doc.respond_to?(:contributors)

      blob = doc['contributors_json_ss'] if doc.respond_to?(:[])
      Hyrax::SolrDocument::Metadata::Solr::CompoundEntries.coerce(blob)
    end
  end
end
