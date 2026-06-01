# frozen_string_literal: true

# Enact PortfolioArtefact - prototype work type, one of four typed siblings
# under a Portfolio. Alternative architecture to the single PortfolioItem
# with a portfolio_item_type discriminator. PortfolioArtefact + PortfolioEvent
# carry geo_locations; PortfolioLiterature carries place_of_publication;
# PortfolioCollection carries extent / extent_type / collection_order.
#
# All attributes (scalar and compound) are declared in
# `config/metadata/portfolio_artefact.yaml`. Compound attributes use
# `type: hash`; each persisted entry is a JSONB hash on the work.
class PortfolioArtefact < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_artefact)
    # See Portfolio for why bulkrax_identifier needs to be on the resource.
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks
  prepend EnactCompoundNormalization

  # Display "Artefact" in pickers / facets / breadcrumbs rather than the
  # default titleized class name "Portfolio Artefact". Matches the UX
  # label from the original PortfolioItem type dropdown.
  def self.human_readable_type
    'Artefact'
  end

  def human_readable_type
    self.class.human_readable_type
  end

  # HykuIndexing hardcodes `object.creator&.first`. Enact has no `creator`
  # field (contributors with typed roles cover that role per CLAUDE.md), so
  # we expose a nil stub purely to keep the shared indexer happy.
  def creator; end
end

PortfolioArtefactResource = PortfolioArtefact unless defined?(PortfolioArtefactResource)
