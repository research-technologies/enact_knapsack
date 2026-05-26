# frozen_string_literal: true

# Enact PortfolioResource / PortfolioItemResource do not have a legacy
# ActiveFedora counterpart class. Hyku's wings.rb installs a
# Valkyrie.config.resource_class_resolver that does
#   `resource_klass_name.gsub(/Resource$/, '').constantize`
# expecting every `*Resource` to have a legacy `*` class (Image, GenericWork,
# Oer, etc.). For PortfolioResource that becomes "Portfolio".constantize, which
# raises NameError mid-save with "uninitialized constant Portfolio".
#
# Wrap the resolver: for known Enact types, constantize the Resource name
# directly; otherwise delegate to the resolver that wings.rb (or any other
# initializer) installed. Re-wraps on every code reload via to_prepare so the
# wings.rb to_prepare block can't drop the wrapper after a dev reload.
ENACT_VALKYRIE_RESOURCES = %w[PortfolioResource PortfolioItemResource].freeze

Rails.application.config.to_prepare do
  prior_resolver = Valkyrie.config.resource_class_resolver
  next if prior_resolver.respond_to?(:enact_wrapper?) && prior_resolver.enact_wrapper?

  wrapped = lambda do |resource_klass_name|
    if ENACT_VALKYRIE_RESOURCES.include?(resource_klass_name)
      resource_klass_name.constantize
    elsif prior_resolver
      prior_resolver.call(resource_klass_name)
    else
      resource_klass_name.constantize
    end
  end
  wrapped.define_singleton_method(:enact_wrapper?) { true }
  Valkyrie.config.resource_class_resolver = wrapped
end
