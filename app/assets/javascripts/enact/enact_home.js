// Reordering the featured cards. Loaded only for a user who can edit the list, which is the only
// case that renders the markup it needs.
//
// Hyku reorders featured works with jQuery nestable, which orders a single-column list; these cards
// are a grid. This writes back into the same `input[data-property=order]` fields Hyku's form posts,
// so the controller is untouched. The handle answers the arrow keys because HTML5 drag and drop is
// mouse-only and this is the only way to order the list.
(function () {
  'use strict';

  var GRID = '[data-featured-grid]';
  var ITEM = '.enact-portfolio';
  var HANDLE = '[data-featured-handle]';
  var MOVE = '[data-featured-move]';
  var STATUS = '[data-featured-status]';
  var UNFEATURE = '[data-featured-unfeature]';

  function items(grid) {
    return Array.prototype.slice.call(grid.querySelectorAll(ITEM));
  }

  function renumber(grid) {
    items(grid).forEach(function (item, index) {
      var field = item.querySelector('input[data-property=order]');
      if (field) field.value = index;
    });
  }

  // Dropping past an item's midpoint means "after", so a card can be moved to the end of a row.
  function dropTarget(grid, dragged, x, y) {
    var over = items(grid).find(function (item) {
      if (item === dragged) return false;
      var box = item.getBoundingClientRect();
      return x >= box.left && x <= box.right && y >= box.top && y <= box.bottom;
    });
    if (!over) return null;

    var box = over.getBoundingClientRect();
    return { item: over, after: x > box.left + box.width / 2 };
  }

  // Function replacements, because a title containing $& or $1 would otherwise be expanded by
  // String#replace rather than inserted.
  function fill(template, item, list) {
    return template
      .replace('%{title}', function () { return item.dataset.title || ''; })
      .replace('%{position}', function () { return list.indexOf(item) + 1; })
      .replace('%{total}', function () { return list.length; });
  }

  function announce(grid, item, template) {
    var status = document.querySelector(STATUS);
    if (!status || !template) return;

    status.textContent = fill(template, item, items(grid));
  }

  function move(grid, item, delta) {
    var list = items(grid);
    var from = list.indexOf(item);
    var to = from + delta;
    // Announced rather than silent, so a screen reader hears why nothing happened.
    if (to < 0 || to >= list.length) {
      announce(grid, item, grid.dataset.atTemplate);
      return false;
    }

    if (delta > 0) {
      list[to].after(item);
    } else {
      list[to].before(item);
    }
    renumber(grid);
    announce(grid, item, grid.dataset.movedTemplate);
    return true;
  }

  function bindDragging(grid) {
    var dragged = null;
    var from = -1;

    // draggable is toggled by the handle rather than left on the card: with it always on, a drag
    // starting over the title or blurb drags the card instead of selecting the text.
    grid.addEventListener('mousedown', function (event) {
      var item = event.target.closest(ITEM);
      if (item) item.draggable = !!event.target.closest(HANDLE);
    });

    grid.addEventListener('dragstart', function (event) {
      dragged = event.target.closest(ITEM);
      if (!dragged) return;
      from = items(grid).indexOf(dragged);
      dragged.classList.add('is-dragging');
      // Firefox will not start a drag without data on the transfer.
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', dragged.dataset.id || '');
    });

    grid.addEventListener('dragover', function (event) {
      if (!dragged) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = 'move';

      var target = dropTarget(grid, dragged, event.clientX, event.clientY);
      if (!target) return;
      if (target.after) {
        target.item.after(dragged);
      } else {
        target.item.before(dragged);
      }
    });

    grid.addEventListener('drop', function (event) {
      if (!dragged) return;
      event.preventDefault();
      renumber(grid);
    });

    grid.addEventListener('dragend', function () {
      if (!dragged) return;
      dragged.classList.remove('is-dragging');
      dragged.draggable = false;
      renumber(grid);
      if (items(grid).indexOf(dragged) !== from) announce(grid, dragged, grid.dataset.movedTemplate);
      dragged = null;
      from = -1;
    });
  }

  function bindButtons(grid) {
    grid.addEventListener('click', function (event) {
      var button = event.target.closest(MOVE);
      if (!button) return;

      event.preventDefault();
      if (move(grid, button.closest(ITEM), Number(button.dataset.featuredMove))) button.focus();
    });
  }

  function bindUnfeature(grid) {
    grid.addEventListener('click', function (event) {
      var link = event.target.closest(UNFEATURE);
      if (!link) return;

      event.preventDefault();
      var item = link.closest(ITEM);
      // Confirmed because the control sits beside the move buttons and the delete is immediate.
      if (grid.dataset.unfeatureConfirm && !window.confirm(grid.dataset.unfeatureConfirm)) return;

      var token = document.querySelector('meta[name=csrf-token]');

      fetch(link.href, {
        method: 'DELETE',
        credentials: 'same-origin',
        headers: { 'X-CSRF-Token': token ? token.content : '', 'X-Requested-With': 'XMLHttpRequest' }
      }).then(function (response) {
        if (!response.ok) return;
        // The card carries the hidden id the form posts, so leaving it would make the next save
        // send a destroyed FeaturedWork id.
        item.remove();
        renumber(grid);
      });
    });
  }

  function bindKeyboard(grid) {
    grid.addEventListener('keydown', function (event) {
      var handle = event.target.closest(HANDLE + ',' + MOVE);
      if (!handle) return;

      // One step in the posted order rather than one grid cell: the column count changes with the
      // viewport, so "left" would mean different things at different widths.
      var delta = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }[event.key];
      if (!delta) return;

      event.preventDefault();
      if (move(grid, handle.closest(ITEM), delta)) handle.focus();
    });
  }

  function start() {
    var grid = document.querySelector(GRID);
    if (!grid) return;

    bindDragging(grid);
    bindKeyboard(grid);
    bindButtons(grid);
    bindUnfeature(grid);
    // The stored order can have gaps if a work was unfeatured.
    renumber(grid);
  }

  // Binding both would double-initialise on the first load.
  if (window.Turbolinks) {
    document.addEventListener('turbolinks:load', start);
  } else {
    document.addEventListener('DOMContentLoaded', start);
  }
})();
