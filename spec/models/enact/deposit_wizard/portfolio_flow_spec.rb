# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::DepositWizard::PortfolioFlow do
  subject(:flow) { described_class.build }

  let(:config) { Hyku::DepositWizard::Config.new }

  # Build a state with the given slots set, then return the visible step names for
  # the current config — the sequence a depositor actually walks. `type_mode` is
  # Enact state, held in State#extra rather than a built-in slot.
  def visible(type_mode: nil, **slots)
    state = Hyku::DepositWizard::State.new({})
    slots.each { |slot, value| state.public_send("#{slot}=", value) }
    state.extra['type_mode'] = type_mode if type_mode
    flow.visible_steps(state, config).map(&:name)
  end

  describe 'the branching routes' do
    it 'new: sets the container type at start, so no type selection shows' do
      expect(visible(path: 'new', work_type: 'Portfolio'))
        .to eq(%w[start files details review])
    end

    it 'add + known: parent, chooser, files, then the work-type picker' do
      expect(visible(path: 'add', type_mode: 'known'))
        .to eq(%w[start select_parent item_start files known_type details review])
    end

    it 'add + guided: parent, chooser, files, then the guided subtype step' do
      expect(visible(path: 'add', type_mode: 'guided'))
        .to eq(%w[start select_parent item_start files guided_confirm details review])
    end

    it 'standalone + known: chooser, files, work-type picker (no parent step)' do
      expect(visible(path: 'standalone', type_mode: 'known'))
        .to eq(%w[start item_start files known_type details review])
    end

    it 'standalone + guided: chooser, files, guided step (no parent step)' do
      expect(visible(path: 'standalone', type_mode: 'guided'))
        .to eq(%w[start item_start files guided_confirm details review])
    end
  end

  describe 'files-before-type' do
    it 'places files before the type step on every add/standalone route' do
      { 'known' => 'known_type', 'guided' => 'guided_confirm' }.each do |mode, type_step|
        seq = visible(path: 'standalone', type_mode: mode)
        expect(seq.index('files')).to be < seq.index(type_step)
      end
    end
  end

  describe 'prerequisites' do
    it 'detours a metadata step to the type step until a work type is set' do
      state = Hyku::DepositWizard::State.new({})
      state.path = 'standalone'
      state.extra['type_mode'] = 'guided'
      expect(flow.detour_for('details', state, config)).to eq('known_type')

      state.work_type = 'PortfolioArtefact'
      expect(flow.detour_for('details', state, config)).to be_nil
    end
  end

  describe 'the progress rail' do
    it 'collapses the type steps into one phase and shows file_detail once files exist' do
      keys = flow.rail(Hyku::DepositWizard::State.new('path' => 'add',
                                                      'extra' => { 'type_mode' => 'guided' },
                                                      'uploaded_file_ids' => ['abc']),
                       config).map { |row| row[:key] }
      expect(keys).to eq(%i[parent type upload detail file_detail review])
    end
  end
end
