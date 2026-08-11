# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::DepositWizard::PresenterDecorator do
  # #continue_in_portfolio_id reads only the stashed deposit hash, so an allocated
  # presenter avoids building the controller context the rest of the class needs.
  let(:presenter) { Hyku::DepositWizard::Presenter.allocate }

  describe '#continue_in_portfolio_id' do
    it 'continues into the portfolio just created' do
      deposited = { 'id' => 'port-1', 'work_type' => 'Portfolio', 'parent_id' => nil }

      expect(presenter.continue_in_portfolio_id(deposited)).to eq('port-1')
    end

    it 'continues into a nested item\'s parent' do
      deposited = { 'id' => 'item-1', 'work_type' => 'PortfolioArtefact', 'parent_id' => 'port-9' }

      expect(presenter.continue_in_portfolio_id(deposited)).to eq('port-9')
    end

    it 'has nowhere to continue for a standalone work' do
      deposited = { 'id' => 'solo-1', 'work_type' => 'PortfolioArtefact', 'parent_id' => nil }

      expect(presenter.continue_in_portfolio_id(deposited)).to be_nil
    end

    it 'has nowhere to continue without a stashed deposit' do
      expect(presenter.continue_in_portfolio_id(nil)).to be_nil
    end
  end
end
