# frozen_string_literal: true

# Enact's guided deposit wizard configuration.
#
# Replaces the generic Hyku wizard defaults with Enact's Portfolio model: the
# four Portfolio child work types, Portfolio as the parent to nest under, and the
# guided item-type sub-flow driven by file-suffix → subtype suggestions.
#
# `Hyku::DepositWizard.config` is a swappable singleton read per request. The
# assignment references app-autoloaded constants (Hyku::DepositWizard, the Flow,
# the Enact service), so it runs in `to_prepare` — after the autoloader is ready,
# and re-run on each dev reload so the config re-applies when those classes change.
# At plain initializer time these constants are not yet loadable (NameError).
Rails.application.config.to_prepare do
  Hyku::DepositWizard.config = Hyku::DepositWizard::Config.new do |c|
    c.container_type = 'Portfolio'
    c.parent_types   = %w[Portfolio]
    c.item_types     = %w[PortfolioArtefact PortfolioEvent
                          PortfolioLiterature PortfolioItemCollection]

    # Enact chooses the parent up front (the "add to an existing work" path +
    # select_parent step), so don't also offer it on the review step.
    c.parent_connect_placement = :start

    # A non-empty suggestions value feeds the guided_confirm step's cards.
    c.suggestions = Enact::DepositWizard::SubtypeSuggestions.compiled

    # The branching flow (new / add / standalone × known / guided). Built in its
    # own class so the step list + skip rules read declaratively.
    c.flow = Enact::DepositWizard::PortfolioFlow.build

    # Nesting on the "add" path uses the stock add_to_parent step (parent_id is
    # already injected into commit_params), so no post_commit hook is needed.
  end
end
