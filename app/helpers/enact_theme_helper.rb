# frozen_string_literal: true

# View helpers for the Enact theme, in one place rather than spread across decorators of
# whichever Hyrax helper each one happens to lean on. Reaches views through
# HykuKnapsack::ApplicationHelper, which Hyku's own ApplicationHelper includes.
#
# Methods calling view_options_for, compound_schema_for, inbound_relationships? and friends
# resolve them from the sibling Hyrax helpers on the same view object.
module EnactThemeHelper
  # How many metadata rows sit above the disclosure.
  VISIBLE_METADATA_ROWS = 8
  MAX_ROWS = 100
  MAX_PAGE = 10_000
  DEFAULT_ROWS = 20

  # ---- tabs ----------------------------------------------------------------

  # [[key, label], ...] in display order, skipping any pane with nothing to show. The first
  # entry is the default tab.
  def enact_show_panes(presenter)
    @enact_show_panes ||= [].tap do |panes|
      panes << [:context, t('enact.show.tabs.context')] if enact_section_present?(enact_context_html(presenter))
      panes << [:metadata, t('enact.show.tabs.metadata')]

      # total_count, not size: these are one page of a paginated list.
      children = enact_child_work_ids(presenter)
      files = enact_file_set_ids(presenter)
      panes << [:items, "#{enact_items_label(presenter)} (#{children.total_count})"] if children.any?
      panes << [:files, "#{t('enact.show.tabs.files')} (#{files.total_count})"] if files.any?
    end
  end

  # Which tab opens. Pager links carry ?pane= so paging reloads onto the tab you were
  # reading: Bootstrap's tab plugin ignores location.hash, and the fragment never reaches
  # the server anyway. Not inferred from items_page/files_page, because Kaminari omits the
  # page param when it is 1, so going back to the first page would drop you on tab one.
  def enact_active_pane(presenter)
    keys = enact_show_panes(presenter).map(&:first)
    requested = params[:pane].to_s.to_sym

    keys.include?(requested) ? requested : keys.first
  end

  # Rendered once and reused: the context pane both tests this for emptiness and prints it.
  def enact_context_html(presenter)
    @enact_context_html ||= render('featured_attributes', presenter:).to_s
  end

  def enact_items_label(presenter)
    t("enact.show.items.#{presenter.model_name.param_key}", default: t('enact.show.items.default'))
  end

  # Text of the rendered fragment, not a whitespace check: Rails wraps every render in
  # BEGIN/END HTML comments in development, which a whitespace check counts as content.
  # Parsing also collapses entities, so a fragment of one &nbsp; is empty. A fragment of
  # only text-free tags (an <hr>, an empty table) counts as empty too, which is the
  # accepted limit of this check.
  def enact_section_present?(html)
    Nokogiri::HTML.fragment(html.to_s).text.strip.present?
  end

  # ---- viewer --------------------------------------------------------------

  def enact_viewer?(presenter)
    presenter.video_embed_viewer? ||
      (presenter.representative_id.present? && presenter.representative_presenter.present?)
  end

  # ---- member panes --------------------------------------------------------

  # One page of ids per pane. Kaminari slices the ordered array and only that page is
  # fetched, which is how Hyrax does it (list_of_item_ids_to_display) and what keeps deposit
  # order without asking Solr to sort: the order lives in the parent's member_ids and the
  # slice never leaves it.
  def enact_file_set_ids(presenter)
    @enact_file_set_ids ||= enact_paginate(presenter.enact_member_ids.first, :files_page)
  end

  def enact_child_work_ids(presenter)
    @enact_child_work_ids ||= enact_paginate(presenter.enact_member_ids.last, :items_page)
  end

  def enact_file_sets(presenter)
    @enact_file_sets ||= presenter.member_presenters(enact_file_set_ids(presenter))
  end

  def enact_child_works(presenter)
    @enact_child_works ||= presenter.member_presenters(enact_child_work_ids(presenter))
  end

  # ---- metadata pane -------------------------------------------------------

  # [above the disclosure, behind it]
  def enact_metadata_rows(presenter, visible: VISIBLE_METADATA_ROWS)
    rows = enact_metadata_fields(presenter)

    [rows.first(visible), rows.drop(visible)]
  end

  # Mirrors Hyku's _attribute_rows.html.erb per-field decisions, because the theme needs
  # the fields as data to group them rather than as rendered markup.
  def enact_metadata_fields(presenter)
    view_options_for(presenter).filter_map do |field, options|
      next if compound_card_field?(presenter, field)

      view_options = conform_options(field, options)
      render_field = conform_field(field, options)

      next unless field == :admin_note ? presenter.editor? : field_visible?(view_options, presenter)

      # Load-bearing, not tidiness: view_options_for returns every profile field and
      # field_visible? reports on view options rather than on whether a value exists, so
      # without this the first-N slice would be mostly fields that render nothing.
      next unless presenter.respond_to?(render_field)
      next if Array(presenter.public_send(render_field)).reject(&:blank?).blank?

      [render_field, view_options]
    end
  end

  # ---- sidebar cards -------------------------------------------------------

  # Either direction shows the card; the reverse lookup is skipped when the work has
  # outbound edges of its own, as render_compound_cards orders it too.
  def enact_relationships_card?(presenter)
    presenter.try(:relationships).present? || inbound_relationships?(presenter)
  end

  # Minus the two the sidebar renders by hand with their own headings, and minus any field
  # with no value. No rescue: compound_schema_for swallows a stale schema itself.
  def enact_card_fields(presenter)
    names = compound_schema_for(presenter).card_compound_names - %i[contributors relationships]

    names.select { |field| presenter.respond_to?(field) && presenter.public_send(field).present? }
  end

  private

  # Each pane reads its own param: two pagers on one page cannot share `page`. rows is
  # shared, matching Hyrax's rows_from_params.
  def enact_paginate(ids, param_name)
    paged = Kaminari.paginate_array(ids, total_count: ids.size)
                    .page(enact_positive_param(param_name, 1, MAX_PAGE))
                    .per(enact_positive_param(:rows, DEFAULT_ROWS, MAX_ROWS))

    # Clamped like Hyrax's current_page: an out-of-range page would render an empty pane.
    paged.out_of_range? && paged.total_pages.positive? ? paged.page(paged.total_pages) : paged
  end

  def enact_positive_param(name, fallback, ceiling)
    digits = params[name].to_s[/\d+/]

    digits.blank? ? fallback : digits.to_i.clamp(1, ceiling)
  end
end
