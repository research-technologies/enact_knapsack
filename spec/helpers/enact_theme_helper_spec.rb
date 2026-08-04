# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnactThemeHelper, type: :helper do
  describe '#enact_section_present?' do
    it 'is false for a fragment whose tags carry no text' do
      expect(helper.enact_section_present?('<hr><table><tr><td></td></tr></table>')).to be(false)
    end

    it 'is false for a fragment that is only an entity' do
      expect(helper.enact_section_present?('&nbsp;')).to be(false)
    end

    it 'is false for the BEGIN/END comments Rails adds around a render in development' do
      expect(helper.enact_section_present?('<!-- BEGIN app/views/x.erb --><!-- END -->')).to be(false)
    end

    it 'is true once there is real text' do
      expect(helper.enact_section_present?('<p>A context statement.</p>')).to be(true)
    end
  end

  describe '#enact_show_panes' do
    let(:presenter) do
      double('presenter', enact_member_ids: [[], []], model_name: double(param_key: 'portfolio'))
    end

    before { allow(helper).to receive(:enact_context_html).and_return('') }

    it 'always offers metadata, and nothing else when the work is bare' do
      expect(helper.enact_show_panes(presenter).map(&:first)).to eq([:metadata])
    end

    it 'adds context only when the statement has text' do
      allow(helper).to receive(:enact_context_html).and_return('<p>Statement</p>')

      expect(helper.enact_show_panes(presenter).map(&:first)).to eq(%i[context metadata])
    end

    it 'adds items and files with their counts, in display order' do
      allow(presenter).to receive(:enact_member_ids).and_return([%w[f1], %w[w1 w2 w3]])

      expect(helper.enact_show_panes(presenter)).to eq(
        [[:metadata, 'Additional information'],
         [:items, 'Portfolio items (3)'],
         [:files, 'Files (1)']]
      )
    end
  end

  it 'pages at twenty, above Hyrax default of ten, so a portfolio is not split mid-sequence' do
    expect(described_class::DEFAULT_ROWS).to eq(20)
  end

  describe '#enact_viewer?' do
    it 'is true for a work with a representative to show' do
      presenter = double('presenter', video_embed_viewer?: false, representative_id: 'fs-1',
                                      representative_presenter: double('file set'))

      expect(helper.enact_viewer?(presenter)).to be(true)
    end

    it 'is true for an embed, which carries its own media' do
      presenter = double('presenter', video_embed_viewer?: true)

      expect(helper.enact_viewer?(presenter)).to be(true)
    end

    it 'is false with no representative, so the default work icon is not given a band' do
      presenter = double('presenter', video_embed_viewer?: false, representative_id: nil)

      expect(helper.enact_viewer?(presenter)).to be(false)
    end

    it 'is false when the representative id points at nothing indexed' do
      presenter = double('presenter', video_embed_viewer?: false, representative_id: 'gone',
                                      representative_presenter: nil)

      expect(helper.enact_viewer?(presenter)).to be(false)
    end
  end

  describe 'member pane pagination' do
    # Ids only: the split and the access filter are the presenter's job, tested there.
    let(:ids) { (1..12).map { |n| "work-#{n}" } }
    let(:presenter) { double('presenter', enact_member_ids: [%w[file-1], ids]) }

    before { stub_const("#{described_class}::DEFAULT_ROWS", 10) }

    it 'returns one page but counts them all' do
      page = helper.enact_child_work_ids(presenter)

      expect(page.size).to eq(10)
      expect(page.total_count).to eq(12)
      expect(page.total_pages).to eq(2)
    end

    it 'reads its own page param, so the two panes move independently' do
      helper.params[:items_page] = '2'

      expect(helper.enact_child_work_ids(presenter).to_a).to eq(%w[work-11 work-12])
      expect(helper.enact_file_set_ids(presenter).to_a).to eq(%w[file-1])
    end

    it 'keeps deposit order across the page boundary' do
      page_one = helper.enact_child_work_ids(presenter).to_a

      # The result is memoised per view context, so page two needs the memo cleared.
      helper.instance_variable_set(:@enact_child_work_ids, nil)
      helper.params[:items_page] = '2'

      expect(page_one + helper.enact_child_work_ids(presenter).to_a).to eq(ids)
    end

    it 'clamps an out-of-range page to the last one, as Hyrax does' do
      helper.params[:items_page] = '99'

      page = helper.enact_child_work_ids(presenter)

      expect(page.current_page).to eq(2)
      expect(page.to_a).to eq(%w[work-11 work-12])
    end

    it 'honours rows, so both panes page at the same size' do
      helper.params[:rows] = '2'

      expect(helper.enact_child_work_ids(presenter).total_pages).to eq(6)
      expect(helper.enact_file_set_ids(presenter).total_pages).to eq(1)
    end

    it 'asks the presenter for the page of presenters, not the whole list' do
      expect(presenter).to receive(:member_presenters) { |page| expect(page.size).to eq(10) }

      helper.enact_child_works(presenter)
    end

    # These reached Kaminari unchecked and raised: it refuses a per-page of 0 and a page
    # number too large for a C long, and an array param has no to_i. A hostile rows array
    # still 500s, but upstream in the show action, before any of this runs.
    it 'falls back to the default rows for a value with no digits' do
      helper.params[:rows] = 'abc'

      expect(helper.enact_child_work_ids(presenter).limit_value).to eq(10)
    end

    it 'clamps rows away from zero' do
      helper.params[:rows] = '0'

      expect(helper.enact_child_work_ids(presenter).limit_value).to eq(1)
    end

    it 'clamps rows to the ceiling' do
      helper.params[:rows] = '999999'

      expect(helper.enact_child_work_ids(presenter).limit_value).to eq(described_class::MAX_ROWS)
    end

    it 'clamps a page number too large for Kaminari to the last page' do
      helper.params[:items_page] = '99999999999999999999'

      expect(helper.enact_child_work_ids(presenter).current_page).to eq(2)
    end

    it 'reads the digits out of an array param instead of raising' do
      helper.params[:rows] = ['5']

      expect(helper.enact_child_work_ids(presenter).limit_value).to eq(5)
    end
  end

  describe '#enact_active_pane' do
    let(:presenter) do
      double('presenter', enact_member_ids: [Array.new(7) { |n| "f#{n}" }, Array.new(12) { |n| "w#{n}" }],
                          model_name: double(param_key: 'portfolio'))
    end

    before { allow(helper).to receive(:enact_context_html).and_return('<p>Statement</p>') }

    it 'is the first pane with no page param' do
      expect(helper.enact_active_pane(presenter)).to eq(:context)
    end

    it 'opens the pane the pager link names' do
      helper.params[:pane] = 'items'

      expect(helper.enact_active_pane(presenter)).to eq(:items)
    end

    it 'opens it on page one too, where Kaminari drops the page param' do
      helper.params[:pane] = 'files'

      expect(helper.enact_file_set_ids(presenter).current_page).to eq(1)
      expect(helper.enact_active_pane(presenter)).to eq(:files)
    end

    it 'ignores a pane that is not being shown' do
      allow(presenter).to receive(:enact_member_ids).and_return([[], Array.new(12) { |n| "w#{n}" }])
      helper.params[:pane] = 'files'

      expect(helper.enact_active_pane(presenter)).to eq(:context)
    end

    it 'ignores a pane that does not exist' do
      helper.params[:pane] = 'nonsense'

      expect(helper.enact_active_pane(presenter)).to eq(:context)
    end

    it 'ignores an array pane instead of raising on it' do
      helper.params[:pane] = ['items']

      expect(helper.enact_active_pane(presenter)).to eq(:context)
    end
  end

  describe '#enact_metadata_rows' do
    let(:presenter) { double('presenter') }
    let(:fields) { (1..11).map { |n| [:"field_#{n}", {}] } }

    before { allow(helper).to receive(:enact_metadata_fields).and_return(fields) }

    it 'puts the first eight above the disclosure and the rest behind it' do
      shown, rest = helper.enact_metadata_rows(presenter)

      expect(shown.size).to eq(8)
      expect(rest.map(&:first)).to eq(%i[field_9 field_10 field_11])
    end

    it 'leaves the disclosure group empty when there is nothing to hide' do
      allow(helper).to receive(:enact_metadata_fields).and_return(fields.first(3))

      expect(helper.enact_metadata_rows(presenter).last).to be_empty
    end

    it 'takes an explicit visible count' do
      shown, = helper.enact_metadata_rows(presenter, visible: 2)

      expect(shown.map(&:first)).to eq(%i[field_1 field_2])
    end
  end

  describe '#enact_metadata_fields' do
    let(:presenter) { double('presenter', editor?: false, title: ['A title'], empty_field: []) }

    before do
      allow(helper).to receive(:view_options_for).and_return(
        title: {}, empty_field: {}, carded: {}, admin_note: {}
      )
      allow(helper).to receive(:compound_card_field?) { |_p, field| field == :carded }
      allow(helper).to receive(:conform_options) { |_f, opts| opts }
      allow(helper).to receive(:conform_field) { |field, _opts| field }
      allow(helper).to receive(:field_visible?).and_return(true)
    end

    it 'keeps only fields that will actually render a value' do
      expect(helper.enact_metadata_fields(presenter).map(&:first)).to eq([:title])
    end
  end

  describe '#enact_relationships_card?' do
    let(:presenter) { double('presenter', id: 'abc') }

    it 'is true on the work\'s own outbound edges, without a reverse lookup' do
      allow(presenter).to receive(:try).with(:relationships).and_return([{ 'item' => 'xyz' }])
      expect(helper).not_to receive(:inbound_relationships?)

      expect(helper.enact_relationships_card?(presenter)).to be_truthy
    end

    it 'is true when something else points at the work' do
      allow(presenter).to receive(:try).with(:relationships).and_return(nil)
      allow(helper).to receive(:inbound_relationships?).and_return(true)

      expect(helper.enact_relationships_card?(presenter)).to be(true)
    end

    it 'is false when neither direction has an edge' do
      allow(presenter).to receive(:try).with(:relationships).and_return([])
      allow(helper).to receive(:inbound_relationships?).and_return(false)

      expect(helper.enact_relationships_card?(presenter)).to be(false)
    end
  end

  describe '#enact_card_fields' do
    let(:presenter) { double('presenter', rights: [{ 'license' => 'cc-by' }], blank: []) }

    before do
      allow(helper).to receive(:compound_schema_for)
        .and_return(double('schema', card_compound_names: %i[contributors relationships rights blank]))
    end

    it 'drops the two the sidebar renders by hand, and any field with no value' do
      expect(helper.enact_card_fields(presenter)).to eq([:rights])
    end
  end
end
