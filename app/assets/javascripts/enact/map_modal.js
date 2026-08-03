/*
 * Opens any [data-map-url] trigger's URL in the shared #enactMapModal iframe.
 * On hide, resets src to about:blank so Cytoscape is torn down and no ghost
 * request is left pending. DOM lookups are deferred to handler time so the
 * listener survives Turbolinks cache restores. enactMapModalReady guards against
 * double-init if the file is included more than once.
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
      // onload assignment (not addEventListener) so re-opens don't stack handlers.
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
