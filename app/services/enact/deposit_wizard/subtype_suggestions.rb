# frozen_string_literal: true

module Enact
  module DepositWizard
    # Compiles the four item-subtype authorities into the data the guided deposit
    # step needs: for an uploaded file's suffix, which subtypes to suggest, and for
    # a chosen subtype, which of the four Portfolio work types to build.
    #
    # Subtypes come from the same authority YAMLs the per-type edit-field partials
    # read (config/authorities/{artefact,event,literature,collection}_type.yml).
    # The file each subtype lives in fixes its work type and badge, so routing is
    # derived, never stored: an authority id resolves to exactly one work type
    # (verified unique across the four files). `file_suffixes:` is the only wizard
    # addition to those YAMLs; a term without it is selectable in the step's full
    # list but never appears as a file-based suggestion.
    module SubtypeSuggestions
      # authority file (without .yml) => [work type class name, badge label]
      AUTHORITIES = {
        'artefact_type' => %w[PortfolioArtefact Artefact],
        'event_type' => %w[PortfolioEvent Event],
        'literature_type' => %w[PortfolioLiterature Literature],
        'collection_type' => %w[PortfolioItemCollection Collection]
      }.freeze

      module_function

      # Every subtype across the four authorities, each tagged with its work type,
      # badge, and file_suffixes. This is also the id => work_type routing table.
      # @return [Array<Hash>] { id:, label:, card_label:, work_type:, badge:, suffixes: }
      def all_subtypes
        @all_subtypes ||= AUTHORITIES.flat_map do |authority, (work_type, badge)|
          terms_for(authority).map do |term|
            { id: term['id'],
              label: term['label'],
              card_label: term['label'],
              work_type:,
              badge:,
              suffixes: Array(term['file_suffixes']).map { |s| s.to_s.downcase } }
          end
        end
      end

      # The subtypes an uploaded extension suggests (case-insensitive), in
      # authority order. An unknown or blank extension yields an empty list.
      def for_suffix(ext)
        ext = ext.to_s.downcase.delete_prefix('.')
        return [] if ext.empty?

        all_subtypes.select { |s| s[:suffixes].include?(ext) }
      end

      def work_type_for(subtype_id)
        index[subtype_id.to_s]&.dig(:work_type)
      end

      def find(subtype_id)
        index[subtype_id.to_s]
      end

      # The value assigned to Hyku::DepositWizard::Config#suggestions. The wizard
      # only checks presence to enable the guided path, so returning the compiled
      # subtypes both turns it on and exposes the data to the step.
      def compiled
        all_subtypes
      end

      def index
        @index ||= all_subtypes.index_by { |s| s[:id] }
      end

      # Reads one authority's terms, raising if the file is missing so a rename or
      # bad path fails fast rather than silently dropping every subtype it holds.
      def terms_for(authority)
        path = HykuKnapsack::Engine.root.join('config', 'authorities', "#{authority}.yml")
        raise "Missing subtype authority: #{path}" unless File.exist?(path)

        YAML.load_file(path)['terms'] || []
      end
    end
  end
end
