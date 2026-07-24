(function () {
  function init() {
    var root = document.querySelector('[data-job-activity]');
    if (!root) { return; }
  }

  document.addEventListener('turbolinks:load', init);
})();
