# frozen_string_literal: true

# Hyrax's default `rights_statement_links` helper assumes the value is a
# rightsstatements.org CV id and looks it up in the QA authority, calling
# `fetch('term')` on the result. For Enact, `rights_statement` carries the
# PR Voices wiki's free-text "metadata rights" statement (CLAUDE.md), which
# isn't in any CV - so the fetch raises KeyError and Catalog#index 500s on
# any document that has the field set.
#
# Make the helper resilient: try the CV lookup, fall back to the literal
# value as the label, and only render an `<a>` when the value looks like a URI.
module HyraxHelperDecorator
  def rights_statement_links(options)
    service = Hyrax.config.rights_statement_service_class.new
    to_sentence(Array(options[:value]).compact_blank.map do |right|
      label =
        begin
          service.label(right)
        rescue StandardError
          right
        end

      if right.to_s.start_with?('http://', 'https://')
        link_to(label, right)
      else
        ERB::Util.h(label)
      end
    end)
  end
end

HyraxHelper.prepend(HyraxHelperDecorator)
