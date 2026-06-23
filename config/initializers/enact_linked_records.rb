# frozen_string_literal: true

# Register Enact's linked_record sources with the generic
# Hyrax::CompoundLinkedRecordResolver. Each source maps a stored reference (a
# row id) to a record, a display label, a show path, a table search (for the
# picker autocomplete), and an inline create. The resolver stays generic; this
# is where Enact says "the :contributors source is Enact::Contributor".
#
# Wrapped in to_prepare so it re-runs on code reload in development and resolves
# the route helper / model lazily.
Rails.application.config.to_prepare do
  Hyrax::CompoundLinkedRecordResolver.register(
    :contributors,
    finder: ->(id) { Enact::Contributor.find_by(id:) },
    label: ->(contributor) { contributor.display_name },
    path: ->(contributor) { HykuKnapsack::Engine.routes.url_helpers.enact_contributor_path(contributor) },
    # Picker autocomplete: the generic linked_record QA authority
    # (/authorities/search/linked_record/contributors) delegates here. Match on
    # name or ORCID via the model scope; shape each row for select2.
    search: lambda { |query|
      Enact::Contributor.matching(query).order(:display_name).limit(20).map do |contributor|
        { id: contributor.id.to_s, label: contributor.display_name, value: contributor.id.to_s }
      end
    },
    # Inline lookup-OR-create: the generic endpoint hands us the submitted
    # attributes; we create the contributor. The create-form field list itself
    # is declared in the m3 profile (create_fields); here we map those fields to
    # the model. `affiliations` is a repeatable scalar (an Array of strings) and
    # `name_identifiers` a repeatable group (an Array of {value, scheme} hashes);
    # both feed the model's multi-valued writers.
    create: lambda { |attrs|
      contributor = Enact::Contributor.new(attrs.slice(:display_name, :orcid, :agent_type))
      contributor.affiliations = attrs[:affiliations] if attrs.key?(:affiliations)
      contributor.name_identifiers = attrs[:name_identifiers] if attrs.key?(:name_identifiers)
      contributor.tap(&:save)
    }
  )
end
