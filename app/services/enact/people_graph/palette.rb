# frozen_string_literal: true

module Enact
  class PeopleGraph
    # Assigns a stable colour to each institution (contributor affiliation)
    # present in a network, and builds the legend rows. Colours are deterministic:
    # institutions are ordered (sorted) and indexed into a fixed palette, so a
    # given institution keeps its swatch across loads. Contributors with no
    # affiliation share a neutral "unaffiliated" swatch.
    #
    # Swatches reuse the approved relationship-map palette; it cycles if a network
    # has more institutions than colours.
    class Palette
      SWATCHES = %w[#6aa9e0 #d2b94e #c074d0 #56b6b6 #7bc95a #d39a52 #c9544b #5b9bd5
                    #b05ec0 #4aa3a3 #c2a83e #7e8aa2].freeze
      UNAFFILIATED_KEY = 'unaffiliated'
      UNAFFILIATED_LABEL = 'Independent / unaffiliated'
      UNAFFILIATED_COLOR = '#9aa2ad'

      # The legend/node key for an affiliation string (its own value, or the
      # shared unaffiliated bucket when blank).
      def self.key_for(affiliation)
        affiliation.presence || UNAFFILIATED_KEY
      end

      # The human label for an affiliation string (the affiliation itself, or the
      # unaffiliated label when blank).
      def self.label_for(affiliation)
        affiliation.presence || UNAFFILIATED_LABEL
      end

      # @param keys [Array<String>] institution keys present across the nodes
      #   (may include duplicates and the unaffiliated key).
      def initialize(keys)
        @order = keys.uniq.reject { |k| k == UNAFFILIATED_KEY }.sort
        @has_unaffiliated = keys.include?(UNAFFILIATED_KEY)
      end

      def color(key)
        return UNAFFILIATED_COLOR if key == UNAFFILIATED_KEY

        SWATCHES[(@order.index(key) || 0) % SWATCHES.length]
      end

      # Legend rows (one per institution present); unaffiliated last when any node
      # has no affiliation. Colours match the nodes.
      def legend
        rows = @order.map { |k| { key: k, label: k, color: color(k) } }
        rows << { key: UNAFFILIATED_KEY, label: UNAFFILIATED_LABEL, color: UNAFFILIATED_COLOR } if @has_unaffiliated
        rows
      end
    end
  end
end
