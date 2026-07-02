// Behaviour for the standalone Enact "research network" people map
// (app/views/enact/people_map/show.html.erb). The page renders with
// `layout: false` and pulls this in with its own `javascript_include_tag`.
// Server data (institutions, contributor nodes, shared-work links) is handed
// over through a `<script type="application/json">` data island so this file
// stays a static, cacheable asset. Precompiled in
// config/initializers/people_map_assets.rb.
//
// Knapsack-local custom code (not a Hyrax override). Same interaction
// vocabulary as the relationship map:
//   - nodes are people/organisations, sized by how many collaborators they have;
//   - colour encodes institution; the legend filters institutions on/off;
//   - hovering spotlights a person and their collaborators (edge weights show);
//   - labels thin out when zoomed out and sharpen as you zoom in;
//   - clicking a person pins the detail panel; clicking a line lists the shared
//     works; layout switches between force/radial/tree and search jumps to a person.
(function () {
  var el = document.getElementById('people-data');
  var D = JSON.parse(el.textContent);
  var INST = {}; D.institutions.forEach(function (i) { INST[i.key] = i; });

  var empty = document.getElementById('empty');
  if (!D.nodes.length) { if (empty) empty.style.display = 'flex'; return; }

  var deg = {}; D.nodes.forEach(function (n) { deg[n.id] = 0; });
  D.links.forEach(function (l) { deg[l.source]++; deg[l.target]++; });
  var sizeFor = function (id) { return 26 + (deg[id] || 0) * 3.2; };

  var elements = D.nodes.map(function (n) {
    return { data: Object.assign({}, n, { sz: sizeFor(n.id), color: (INST[n.inst] || {}).color || n.instColor || '#9aa2ad', deg: deg[n.id] || 0 }) };
  }).concat(D.links.map(function (l, i) {
    return { data: { id: 'e' + i, source: l.source, target: l.target, weight: l.weight, works: l.works, w: 1 + l.weight * 1.6 } };
  }));

  var legend = document.getElementById('legend');
  var hidden = new Set();
  D.institutions.forEach(function (it) {
    var row = document.createElement('div');
    row.className = 'lrow'; row.dataset.inst = it.key;
    row.setAttribute('role', 'checkbox'); row.setAttribute('aria-checked', 'true'); row.tabIndex = 0;
    row.innerHTML = '<span class="lcheck" aria-hidden="true"></span><span class="dot" style="background:' + it.color + '"></span><span>' + it.label + '</span>';
    legend.appendChild(row);
  });

  var cy = cytoscape({
    container: document.getElementById('cy'), elements: elements, minZoom: 0.3, maxZoom: 2.4, wheelSensitivity: 0.3,
    style: [
      { selector: 'node', style: {
        'background-color': 'data(color)', 'width': 'data(sz)', 'height': 'data(sz)',
        'border-color': '#0e1014', 'border-width': 1.5,
        'label': 'data(label)', 'color': '#cfd5de', 'font-size': 10, 'font-family': 'system-ui,sans-serif',
        'text-valign': 'bottom', 'text-halign': 'center', 'text-margin-y': 5, 'text-wrap': 'wrap', 'text-max-width': 110,
        'transition-property': 'opacity', 'transition-duration': '150ms' } },
      { selector: 'node[agent_type = "organization"]', style: { 'shape': 'round-rectangle', 'width': 52, 'height': 30 } },
      { selector: 'node.primary', style: { 'border-color': '#ffffff', 'border-width': 3 } },
      { selector: 'edge', style: { 'line-color': '#5b6270', 'width': 'data(w)', 'curve-style': 'bezier', 'opacity': 0.55,
        'font-size': 9, 'color': '#c7ccd4', 'text-background-color': '#14161a', 'text-background-opacity': 1, 'text-background-padding': 2,
        'transition-property': 'opacity', 'transition-duration': '150ms' } },
      { selector: 'edge.show-label', style: { 'label': 'data(weight)', 'line-color': '#8a93a3', 'opacity': 0.95 } },
      { selector: 'node.hidelabel', style: { 'text-opacity': 0 } },
      { selector: '.faded', style: { 'opacity': 0.07 } },
      { selector: 'node.faded', style: { 'text-opacity': 0 } }
    ]
  });

  var LAYOUTS = {
    cose: { name: 'cose', animate: false, fit: true, padding: 70, nodeRepulsion: 45000, idealEdgeLength: 150, nodeOverlap: 36, componentSpacing: 170, gravity: 0.28 },
    concentric: { name: 'concentric', animate: false, fit: true, padding: 60, concentric: function (n) { return n.data('deg'); }, levelWidth: function () { return 2; }, minNodeSpacing: 40 },
    breadthfirst: { name: 'breadthfirst', animate: false, fit: true, padding: 60, spacingFactor: 1.05 }
  };
  var activeLayout = 'cose', pinned = null;
  function updateZoom() { var z = cy.zoom(); cy.nodes().forEach(function (n) { var keep = z > 0.6 || (n.data('deg') || 0) >= 4; n[keep ? 'removeClass' : 'addClass']('hidelabel'); }); }
  cy.on('zoom', updateZoom);

  function spotlight(n) { cy.elements().addClass('faded'); var nb = n.closedNeighborhood(); nb.removeClass('faded'); nb.edges().addClass('show-label'); }
  function clearSpot() { cy.elements().removeClass('faded'); cy.edges().removeClass('show-label'); }
  cy.on('mouseover', 'node', function (e) { if (!pinned) spotlight(e.target); });
  cy.on('mouseout', 'node', function () { if (!pinned) clearSpot(); });

  var DETAIL = document.getElementById('detail');
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]; }); }
  function nameOf(id) { var n = D.nodes.find(function (x) { return x.id === id; }); return n ? n.label : id; }
  function showPerson(n) {
    var d = n.data(), it = INST[d.inst] || {};
    var h = '<h4>' + esc(d.label) + '</h4><div class="drow-sub"><span class="dot" style="background:' + (it.color || d.instColor) + '"></span>' + esc(it.label || d.instLabel || '') + (d.agent_type === 'organization' ? ' &middot; organisation' : '') + '</div>';
    if (d.orcid) h += '<div class="row"><b class="orcid">ORCID</b> ' + esc(d.orcid) + '</div>';
    h += '<div class="row"><b>' + d.works + '</b> work' + (d.works === 1 ? '' : 's') + ' &middot; <b>' + d.deg + '</b> collaborator' + (d.deg === 1 ? '' : 's') + '</div>';
    if (d.roles && d.roles.length) { h += '<div class="row" style="margin-top:10px">'; d.roles.forEach(function (r) { h += '<span class="badge">' + esc(r) + '</span>'; }); h += '</div>'; }
    h += '<a class="profilelink" href="' + esc(d.path || '#') + '">&#8599; View full profile</a>';
    DETAIL.innerHTML = h;
  }
  function showEdge(e) {
    var a = nameOf(e.data('source')), b = nameOf(e.data('target')), works = e.data('works') || [];
    var h = '<h4 style="font-size:16px">' + esc(a) + ' <span style="color:var(--muted)">+</span> ' + esc(b) + '</h4>';
    h += '<div class="row"><b>' + works.length + '</b> shared work' + (works.length === 1 ? '' : 's') + '</div><ul class="worklist">';
    works.forEach(function (w) { h += '<li>' + esc(w) + '</li>'; }); h += '</ul>';
    DETAIL.innerHTML = h;
  }
  function reset() { DETAIL.innerHTML = '<p class="hint">Hover a <b>person</b> to spotlight their collaborators; click to pin their details. Click a <b>line</b> to see the works two people share.</p>'; }
  cy.on('tap', 'node', function (e) { pinned = e.target; clearSpot(); spotlight(e.target); cy.nodes().removeClass('primary'); e.target.addClass('primary'); showPerson(e.target); });
  cy.on('tap', 'edge', function (e) { showEdge(e.target); });
  cy.on('tap', function (e) { if (e.target === cy) { pinned = null; clearSpot(); cy.nodes().removeClass('primary'); reset(); } });

  function applyFilter() {
    cy.nodes().forEach(function (n) { if (hidden.has(n.data('inst'))) { n.style('display', 'none'); } else { n.removeStyle('display'); } });
    cy.edges().forEach(function (e) {
      var hide = hidden.has(cy.getElementById(e.data('source')).data('inst')) || hidden.has(cy.getElementById(e.data('target')).data('inst'));
      if (hide) { e.style('display', 'none'); } else { e.removeStyle('display'); }
    });
  }
  legend.querySelectorAll('.lrow').forEach(function (row) {
    var toggle = function () {
      var k = row.dataset.inst;
      if (hidden.has(k)) { hidden.delete(k); row.classList.remove('off'); } else { hidden.add(k); row.classList.add('off'); }
      row.setAttribute('aria-checked', String(!hidden.has(k))); applyFilter();
    };
    row.addEventListener('click', toggle);
    row.addEventListener('keydown', function (ev) { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); toggle(); } });
  });

  document.querySelectorAll('#layoutswitch button').forEach(function (b) {
    b.addEventListener('click', function () {
      activeLayout = LAYOUTS[b.dataset.layout] ? b.dataset.layout : 'cose';
      document.querySelectorAll('#layoutswitch button').forEach(function (x) { x.setAttribute('aria-pressed', String(x.dataset.layout === activeLayout)); });
      pinned = null; clearSpot(); cy.nodes().removeClass('primary'); reset();
      cy.layout(LAYOUTS[activeLayout]).run(); cy.fit(cy.elements(), 60); updateZoom();
    });
  });

  var search = document.getElementById('search');
  search.addEventListener('input', function () {
    var q = search.value.trim().toLowerCase(); if (pinned) return;
    if (!q) { cy.nodes().removeClass('faded'); updateZoom(); return; }
    cy.nodes().forEach(function (n) { var hit = (n.data('label') || '').toLowerCase().indexOf(q) !== -1; n[hit ? 'removeClass' : 'addClass']('faded'); if (hit) n.removeClass('hidelabel'); });
  });
  search.addEventListener('keydown', function (ev) {
    if (ev.key !== 'Enter') return; var q = search.value.trim().toLowerCase(); if (!q) return;
    var m = cy.nodes().filter(function (n) { return (n.data('label') || '').toLowerCase().indexOf(q) !== -1; })[0];
    if (m) { cy.nodes().removeClass('faded'); pinned = m; cy.nodes().removeClass('primary'); m.addClass('primary'); spotlight(m); showPerson(m); cy.animate({ center: { eles: m }, zoom: 1.3 }, { duration: 300 }); }
  });

  cy.ready(function () { cy.layout(LAYOUTS.cose).run(); cy.fit(cy.elements(), 60); updateZoom(); });
})();
