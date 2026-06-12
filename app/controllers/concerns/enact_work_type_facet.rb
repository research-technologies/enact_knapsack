# frozen_string_literal: true

# Shared behavior for the "Work Type" facet (has_model_ssim) used on both the
# dashboard Works page and the catalog search page.
module EnactWorkTypeFacet
  # Adds the facet to a controller's Blacklight config, once. Guarded because
  # the knapsack reloads decorator files on every code reload
  # (config.to_prepare) and Blacklight raises on a duplicate facet key.
  def self.add_facet_to(controller_class, limit: 10)
    controller_class.include(self)
    controller_class.helper_method :enact_work_type_facet_label
    return if controller_class.blacklight_config.facet_fields.key?('has_model_ssim')

    controller_class.blacklight_config.add_facet_field(
      'has_model_ssim',
      label: 'Work Type',
      helper_method: :enact_work_type_facet_label,
      limit: limit
    )
  end

  # Blacklight passes a facet item (not a bare string); unwrap it first.
  # The activerecord.models.* locale entries are pluralized (one:/other:),
  # which model_name.human does not resolve, so look them up with an explicit
  # count. Falls back to titleizing unknown values so the facet never breaks
  # on stale index data.
  def enact_work_type_facet_label(value)
    name = (value.respond_to?(:value) ? value.value : value).to_s
    klass = name.safe_constantize
    return name.titleize unless klass.respond_to?(:model_name)

    I18n.t("activerecord.models.#{klass.model_name.i18n_key}", count: 1, default: name.titleize)
  end
end
