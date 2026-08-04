# frozen_string_literal: true

require 'rails_helper'

# :clean_repo because these examples index works: the suite shares one Solr core and only wipes it
# for that tag.
RSpec.describe Hyrax::HomepageControllerDecorator, :clean_repo, type: :controller do
  # Written out rather than taken from a factory because Hyrax ships one only for its own test work
  # class. Access is assigned to the *saved* resource: the permission manager belongs to the object
  # it was built for, so assigning before the save persists nothing and the work indexes as
  # restricted whatever was asked for.
  def work(klass, title, visibility, member_ids = [])
    saved = Hyrax.persister.save(resource: klass.new(title: [title], member_ids:))
    Hyrax::VisibilityWriter.new(resource: saved).assign_access_for(visibility:)
    saved.permission_manager.acl.save
    Hyrax.index_adapter.save(resource: saved)
    saved
  end

  def portfolio(title, visibility, member_ids = [])
    work(Portfolio, title, visibility, member_ids)
  end

  let(:private_portfolio) { portfolio('Kiln Yard', 'restricted') }
  let(:public_portfolio) { portfolio('Primary Space', 'open') }

  controller(Hyrax::HomepageController) do
  end

  before do
    allow(controller).to receive(:home_page_theme).and_return('enact_home')
  end

  describe 'the featured works a visitor is shown' do
    it 'drops a work featured while public and since made private' do
      FeaturedWork.create!(work_id: public_portfolio.id.to_s, order: 0)
      FeaturedWork.create!(work_id: private_portfolio.id.to_s, order: 1)

      get :index

      featured = assigns(:enact_home_featured).map { |work| work.presenter.id }

      expect(featured).to include(public_portfolio.id.to_s)
      expect(featured).not_to include(private_portfolio.id.to_s)
    end

    it 'filters in the decorator, because the list Hyrax hands over is not access-filtered' do
      FeaturedWork.create!(work_id: private_portfolio.id.to_s, order: 0)

      get :index

      expect(assigns(:featured_work_list).featured_works.map(&:work_id)).to include(private_portfolio.id.to_s)
      expect(assigns(:enact_home_featured)).to be_empty
    end
  end

  describe 'the counts band' do
    it 'counts only what the visitor may see' do
      public_portfolio
      private_portfolio

      get :index

      expect(assigns(:enact_home_counts)).to eq(items: 1, portfolios: 1)
    end

    # A nil count reaching a pluralised translation renders the translation hash.
    it 'sets both counts on an empty repository rather than leaving them nil' do
      get :index

      expect(assigns(:enact_home_counts)).to eq(items: 0, portfolios: 0)
    end
  end

  describe 'the browse facets' do
    it 'offers a work type the visitor can see, and never Portfolio, which the band reports' do
      artefact = Hyrax.persister.save(resource: PortfolioArtefact.new(title: ['Site sketchbook']))
      Hyrax::VisibilityWriter.new(resource: artefact).assign_access_for(visibility: 'open')
      artefact.permission_manager.acl.save
      Hyrax.index_adapter.save(resource: artefact)
      public_portfolio

      get :index

      expect(assigns(:enact_home_work_types)).to eq('PortfolioArtefact' => 1)
    end

    it 'offers nothing on an empty repository, so the module hides rather than listing zeroes' do
      get :index

      expect(assigns(:enact_home_work_types)).to be_empty
    end
  end

  # The restriction lives in q, not fq, because SearchBuilder#merge would replace the chain's own
  # fq and with it the access filter. Nothing about that is visible in the count, so this example is
  # the guard: move the terms query into fq and it fails.
  describe 'the item count on a featured card' do
    it 'counts only the children a visitor may see' do
      visible = work(PortfolioArtefact, 'Site sketchbook', 'open')
      hidden = work(PortfolioArtefact, 'Unreleased maquette', 'restricted')
      parent = portfolio('Lighthouse Keepers', 'open', [visible.id, hidden.id])
      FeaturedWork.create!(work_id: parent.id.to_s, order: 0)

      get :index

      expect(assigns(:enact_home_item_counts)[parent.id.to_s]).to eq(1)
    end
  end
end
