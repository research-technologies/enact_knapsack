# frozen_string_literal: true

module Enact
  module MapModalHelper
    # Renders a link that opens the enactMapModal iframe modal when JS is available.
    # Falls back to direct navigation to the standalone map page without JS.
    # html_class is the only caller-specific attribute; data-* and aria-* are
    # identical on every trigger and live here so the modal ID is never repeated in templates.
    def enact_map_trigger(label, url, html_class: 'btn btn-outline-secondary btn-sm')
      link_to label, url,
              class: html_class,
              data: { map_url: url, map_title: label },
              aria: { haspopup: 'dialog', controls: 'enactMapModal' }
    end
  end
end
