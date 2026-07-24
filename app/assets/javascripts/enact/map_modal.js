/*
 * Initialiser for the enactMapModal iframe modal. Listens for clicks on any
 * [data-map-url] element, loads that URL into the iframe, copies
 * data-map-title to the modal heading, then opens the Bootstrap modal. Clears
 * the iframe src to about:blank on hide so Cytoscape is torn down and no ghost
 * request is left pending.
 *
 * window.enactMapModalReady guards against double-init if this file is somehow
 * included more than once on the same page.
 */
(function () {
  if (window.enactMapModalReady) return;
  window.enactMapModalReady = true;

  function setup() {
    var modal = document.getElementById('enactMapModal');
    if (!modal) return;
    var iframe = document.getElementById('enactMapIframe');
    var titleEl = document.getElementById('enactMapModalLabel');

    document.body.addEventListener('click', function (e) {
      var trigger = e.target.closest('[data-map-url]');
      if (!trigger) return;
      e.preventDefault();
      var url = trigger.getAttribute('data-map-url');
      var title = trigger.getAttribute('data-map-title') || '';
      iframe.src = url;
      iframe.title = title;
      titleEl.textContent = title;
      $(modal).modal('show');
    });

    $(modal).on('hidden.bs.modal', function () {
      iframe.src = 'about:blank';
      iframe.title = '';
      titleEl.textContent = '';
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
}());
