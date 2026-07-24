/*
 * Initialiser for the enactMapModal iframe modal. Listens for clicks on any
 * [data-map-url] element, loads that URL into the iframe, copies
 * data-map-title to the modal heading, then opens the Bootstrap modal. Clears
 * the iframe src to about:blank on hide so Cytoscape is torn down and no ghost
 * request is left pending.
 *
 * DOM lookups are deferred to handler time so the listener survives Turbolinks
 * cache restores without holding stale element references.
 *
 * window.enactMapModalReady guards against double-init if this file is somehow
 * included more than once on the same page.
 */
(function () {
  if (window.enactMapModalReady) return;
  window.enactMapModalReady = true;

  function setup() {
    if (!document.getElementById('enactMapModal')) return;

    document.body.addEventListener('click', function (e) {
      var trigger = e.target.closest('[data-map-url]');
      if (!trigger) return;
      var modal = document.getElementById('enactMapModal');
      if (!modal) return;
      e.preventDefault();
      var iframe  = document.getElementById('enactMapIframe');
      var titleEl = document.getElementById('enactMapModalLabel');
      var title = trigger.getAttribute('data-map-title') || '';
      iframe.src          = trigger.getAttribute('data-map-url');
      iframe.title        = title;
      titleEl.textContent = title;
      $(modal).modal('show');
    });

    $(document.body).on('hidden.bs.modal', '#enactMapModal', function () {
      document.getElementById('enactMapIframe').src          = 'about:blank';
      document.getElementById('enactMapIframe').title        = '';
      document.getElementById('enactMapModalLabel').textContent = '';
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
}());
