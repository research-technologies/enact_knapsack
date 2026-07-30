/*
 * Initialiser for the enactMapModal iframe modal. Listens for clicks on any
 * [data-map-url] element, loads that URL into the iframe, copies
 * data-map-title to the modal heading, then opens the Bootstrap modal. A
 * loading overlay (#enactMapLoading) is shown until the iframe fires `load`,
 * so the modal never shows a blank body while the map page loads and boots.
 * Clears the iframe src to about:blank on hide so Cytoscape is torn down and
 * no ghost request is left pending.
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
      var loading = document.getElementById('enactMapLoading');
      var titleEl = document.getElementById('enactMapModalLabel');
      var title = trigger.getAttribute('data-map-title') || '';
      // Show the loading overlay until the map page finishes loading. onload
      // (assignment, not addEventListener) so re-opens never stack listeners,
      // and lookups stay at handler time per the Turbolinks-safe pattern above.
      if (loading) {
        loading.classList.remove('is-hidden');
        iframe.onload = function () { loading.classList.add('is-hidden'); };
      }
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
