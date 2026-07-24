/*
 * Initialiser for the enactMapModal iframe modal. Listens for clicks on any
 * [data-map-url] element, loads that URL into the iframe, copies
 * data-map-title to the modal heading, then opens the Bootstrap modal.
 *
 * The iframe is NOT cleared on close - preserving the loaded page so re-opens
 * within the same session are instant. Staleness is handled two ways:
 *   - Relationship map URLs include a ?t=<timestamp> param derived from the
 *     work's system_modified_dtsi. A URL change means the work was edited;
 *     the iframe reloads automatically because currentUrl no longer matches.
 *   - People map URLs have no timestamp (stale signal is tenant-wide). An
 *     age check reloads the iframe after STALE_MS regardless of URL equality.
 *
 * window.enactMapModalReady guards against double-init if this file is somehow
 * included more than once on the same page.
 */
(function () {
  if (window.enactMapModalReady) return;
  window.enactMapModalReady = true;

  var STALE_MS = 5 * 60 * 1000;
  var currentUrl = null;

  function setup() {
    if (!document.getElementById('enactMapModal')) return;

    var iframe = document.getElementById('enactMapIframe');

    iframe.addEventListener('load', function () {
      if (iframe.src && iframe.src !== 'about:blank') {
        iframe.dataset.loadedAt = Date.now();
      }
    });

    document.body.addEventListener('click', function (e) {
      var trigger = e.target.closest('[data-map-url]');
      if (!trigger) return;
      var modal = document.getElementById('enactMapModal');
      if (!modal) return;
      e.preventDefault();

      var titleEl = document.getElementById('enactMapModalLabel');
      var url   = trigger.getAttribute('data-map-url');
      var title = trigger.getAttribute('data-map-title') || '';

      var loadedAt = parseInt(iframe.dataset.loadedAt || '0', 10);
      var isFresh  = currentUrl === url && loadedAt && (Date.now() - loadedAt) < STALE_MS;

      if (!isFresh) {
        iframe.src = url;
        currentUrl = url;
      }
      iframe.title        = title;
      titleEl.textContent = title;
      $(modal).modal('show');
    });

    $(document.body).on('hidden.bs.modal', '#enactMapModal', function () {
      document.getElementById('enactMapModalLabel').textContent = '';
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
}());
