// enact_show theme: the Cite card's style picker and copy button.
(function () {
  'use strict';

  // WeakSet, not a data attribute: Turbolinks caches pages by cloning the body, which
  // copies attributes but not listeners, so a DOM flag would survive into a dead clone.
  var bound = new WeakSet();

  function showStyle(root, style) {
    root.querySelectorAll('[data-enact-cite-text]').forEach(function (block) {
      block.hidden = block.getAttribute('data-enact-cite-text') !== style;
    });
  }

  function visibleText(root) {
    var shown = root.querySelector('[data-enact-cite-text]:not([hidden])');
    return shown ? shown.textContent.trim() : '';
  }

  function init() {
    document.querySelectorAll('[data-enact-cite]').forEach(function (root) {
      if (bound.has(root)) return;
      bound.add(root);

      var picker = root.querySelector('[data-enact-cite-picker]');
      if (picker) {
        picker.addEventListener('change', function () { showStyle(root, picker.value); });
      }

      var copy = root.querySelector('[data-enact-cite-copy]');
      if (!copy) return;

      // Insecure context: the text is selectable, so drop the button rather than
      // leave one that does nothing.
      if (!navigator.clipboard) {
        copy.hidden = true;
        return;
      }

      var flag = root.querySelector('[data-enact-cite-copied]');
      var timer = null;

      function setCopied(on) {
        if (flag) flag.hidden = !on;
        copy.classList.toggle('is-copied', on);
      }

      function clear() {
        window.clearTimeout(timer);
        timer = null;
      }

      copy.addEventListener('click', function () {
        // Synchronous, not in the clipboard callback: the button is already teal under
        // :active, and awaiting the promise flicks it back to yellow in between.
        setCopied(true);

        // Cancel any pending timer, or an earlier timeout clears the state while a
        // later click still expects it shown.
        clear();
        timer = window.setTimeout(function () { setCopied(false); }, 1500);

        navigator.clipboard.writeText(visibleText(root)).catch(function () {
          clear();
          setCopied(false);
        });
      });
    });
  }

  if (window.Turbolinks) {
    document.addEventListener('turbolinks:load', init);
  } else {
    document.addEventListener('DOMContentLoaded', init);
  }

  // Also run now: mergeHead appends this script after turbolinks:load has already fired,
  // so the listener would miss the page view that loaded it. The WeakSet makes it a no-op.
  init();
})();
