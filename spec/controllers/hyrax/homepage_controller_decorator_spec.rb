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
end
