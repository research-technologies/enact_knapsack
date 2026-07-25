(function () {
  var POLL_MS = 5000;
  var timer = null;

  function inFlight(root) {
    return root.querySelector('[data-state="running"], [data-state="retrying"], [data-state="pending"]');
  }

  // Re-attach open-state memory after each render so a manual toggle survives a poll swap.
  function track(root, userState) {
    root.querySelectorAll('[data-work], [data-file-set]').forEach(function (el) {
      var id = el.getAttribute('data-work') || el.getAttribute('data-file-set');
      if (!id) { return; }
      if (id in userState) { el.open = userState[id]; }
      el.addEventListener('toggle', function () { userState[id] = el.open; });
    });
  }

  function init() {
    if (timer) { clearInterval(timer); timer = null; }

    var root = document.querySelector('[data-job-activity]');
    if (!root) { return; }

    var body = root.querySelector('[data-job-activity-body]');
    var url = root.getAttribute('data-poll-url');
    var userState = {};

    track(root, userState);
    if (!body || !url) { return; }

    var idle = 0;
    var fetching = false;
    timer = setInterval(function () {
      if (fetching) { return; } // one request at a time; skip if the last is still running
      fetching = true;
      fetch(url, { headers: { 'X-Requested-With': 'XMLHttpRequest' }, credentials: 'same-origin' })
        .then(function (res) { return res.ok ? res.text() : null; })
        .then(function (html) {
          if (html === null) { return; }
          body.innerHTML = html;
          track(root, userState);
          idle = inFlight(root) ? 0 : idle + 1;
          if (idle >= 3) { clearInterval(timer); timer = null; }
        })
        .catch(function () {})
        .then(function () { fetching = false; });
    }, POLL_MS);
  }

  function stop() { if (timer) { clearInterval(timer); timer = null; } }

  // With Turbolinks, turbolinks:load fires on the initial load and every visit,
  // so binding it alone avoids the double init that DOMContentLoaded + turbolinks:load
  // causes on first load. Fall back to DOMContentLoaded only when Turbolinks is absent.
  if (window.Turbolinks) {
    document.addEventListener('turbolinks:load', init);
    document.addEventListener('turbolinks:before-cache', stop);
    document.addEventListener('turbolinks:before-visit', stop);
  } else if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
