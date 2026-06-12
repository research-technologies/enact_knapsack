# frozen_string_literal: true

# OVERRIDE Hyrax 5.2 / Hyku: add a "Work type" dropdown to the dashboard Works
# filter row (next to Visibility / Status / Admin Set).
#
# The filter row renders every facet configured on this controller as a
# dropdown (hyrax/my/works/_facets.html.erb via
# Hyrax::DropdownFacetFieldComponent), so declaring the facet is all it takes.
# Values are model class names; the label helper turns them into the human
# names from config/locales (activerecord.models.*), so depositors see
# "Portfolio" / "Artefact" / "Event", not "PortfolioItemCollection".
#
# The helper lives here (controller + helper_method) rather than in
# app/helpers because the engine-helper inclusion happens once at boot and
# does not survive dev code reloads; this file is re-applied on every reload.
#
# Named *EnactDecorator because Hyku already ships a
# Hyrax::My::WorksControllerDecorator (sort fields) and this file must define
# its own Zeitwerk-matching constant.
module Hyrax
  module My
    module WorksControllerEnactDecorator
      # Blacklight passes a facet item (not a bare string); unwrap it first.
      # The activerecord.models.* locale entries are pluralized (one:/other:),
      # which model_name.human does not resolve, so look them up with an
      # explicit count. Falls back to titleizing unknown values so the facet
      # never breaks on stale index data.
      def enact_work_type_facet_label(value)
        name = (value.respond_to?(:value) ? value.value : value).to_s
        klass = name.safe_constantize
        return name.titleize unless klass.respond_to?(:model_name)

        I18n.t("activerecord.models.#{klass.model_name.i18n_key}", count: 1, default: name.titleize)
      end
    end
  end
end

Hyrax::My::WorksController.include Hyrax::My::WorksControllerEnactDecorator
Hyrax::My::WorksController.helper_method :enact_work_type_facet_label

# Guarded because the knapsack reloads decorator files on every code reload
# (config.to_prepare) and Blacklight raises on a duplicate facet key.
unless Hyrax::My::WorksController.blacklight_config.facet_fields.key?('has_model_ssim')
  Hyrax::My::WorksController.blacklight_config.add_facet_field(
    'has_model_ssim',
    label: 'Work Type',
    helper_method: :enact_work_type_facet_label,
    limit: 10
  )
end
