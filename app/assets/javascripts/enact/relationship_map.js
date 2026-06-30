// Behaviour for the standalone Enact relationship-map page
// (app/views/enact/relationship_map/show.html.erb). The page renders with
// `layout: false` and pulls this in with its own `javascript_include_tag`.
// Server data (relation-type metadata, the node/link graph, and the optional
// focus id) is handed over through a `<script type="application/json">` data
// island so this file stays a static, cacheable asset. Precompiled in
// config/initializers/relationship_map_assets.rb.
//
// Knapsack-local custom code (not a Hyrax override). The visualisation follows
// the "Proposed direction" signed off with Nick (see
// docs/relationship-map-usability-audit.md): clarity over a full-web dump.
//   - nodes are sized by how connected they are (the hub anchors the view);
//   - a coloured ring encodes the work type over the thumbnail;
//   - hovering spotlights a work and its direct links (Obsidian-style), and
//     edge labels only appear for what is spotlighted;
//   - labels thin out when zoomed out and sharpen as you zoom in;
//   - the legend filters by relationship type, layout switches between
//     force/radial/tree, and a search box jumps to a work.
// Click still opens the focused ego-graph + detail panel, as before.
(function () {
  function init() {
    var dataEl = document.getElementById('relationship-map-data');
    if (!dataEl) { return; }
    var payload = JSON.parse(dataEl.textContent);

    const REL = payload.rel_types || {};
    const relColor = e => (REL[e.data('rel')] || { color: '#888' }).color;
    const relLabelOf = r => (REL[r] || { label: r }).label;
    const relInverseOf = r => (REL[r] || {}).inverse || relLabelOf(r);

    const G = { nodes: payload.graph.nodes || [], links: payload.graph.links || [] };
    const FOCUS = payload.focus || '';

    // Work-type -> ring colour. Keyed by the model class string the controller
    // sends as `type` (PortfolioArtefact, PortfolioEvent, ...). External-URL
    // nodes keep their own dashed-chip style, so they are not listed here.
    const TYPE_COLOR = {
      PortfolioArtefact: '#6aa9e0',
      PortfolioEvent: '#d2b94e',
      PortfolioLiterature: '#c074d0',
      Portfolio: '#7bc95a'
    };
    const TYPE_LABEL = {
      PortfolioArtefact: 'Artefact', PortfolioEvent: 'Event',
      PortfolioLiterature: 'Literature', Portfolio: 'Portfolio'
    };
    const typeColor = t => TYPE_COLOR[t] || '#b7bcc4';

    // degree (number of links) per node, for size-by-connections
    const degree = {};
    G.nodes.forEach(n => { degree[n.id] = 0; });
    G.links.forEach(l => { if (degree[l.source] != null) degree[l.source]++; if (degree[l.target] != null) degree[l.target]++; });
    const sizeFor = id => 30 + (degree[id] || 0) * 4; // links 0..12 -> 30..78px

    // legend (independent of the graph); rows are clickable to filter edge types
    const hiddenRels = new Set();
    const legendEl = document.getElementById('rel-legend');
    Object.keys(REL).forEach(k => {
      const row = document.createElement('div');
      row.className = 'row filterable';
      row.setAttribute('role', 'button');
      row.setAttribute('tabindex', '0');
      row.dataset.rel = k;
      row.innerHTML = `<span class="swatch" style="border-color:${REL[k].color}"></span>`
        + `<span>${REL[k].label} <span class="datacite">${REL[k].dc}</span></span>`;
      legendEl.appendChild(row);
    });

    function buildGraph() {
      const container = document.getElementById('cy');
      // Wait until the flex container has a real size; cose run in a 0x0 box
      // collapses/blank-renders. Retry on the next frame until it's measured.
      if (!container.clientWidth || !container.clientHeight) { requestAnimationFrame(buildGraph); return; }
      if (!window.cytoscape) { requestAnimationFrame(buildGraph); return; }

      document.getElementById('empty').style.display = 'none';
      const elements = [
        // carry all fields (thumb, type, date, keywords, description...) plus the
        // derived size + ring colour so the stylesheet can map them per node.
        ...G.nodes.map(n => ({ data: { ...n, sz: sizeFor(n.id), tcolor: typeColor(n.type) } })),
        ...G.links.map((l, i) => ({ data: { id: 'e' + i, source: l.source, target: l.target, rel: l.rel, note: l.note, rl: relLabelOf(l.rel) } }))
      ];

      // Shared force-directed layout. Roomy spacing so the full project web
      // (~27 nodes) reads clearly; fit:true zooms to show everything.
      const COSE = { name: 'cose', animate: false, fit: true, padding: 80,
        nodeRepulsion: 50000, idealEdgeLength: 240, nodeOverlap: 48,
        componentSpacing: 220, gravity: 0.2 };
      const LAYOUTS = {
        cose: COSE,
        concentric: { name: 'concentric', animate: false, fit: true, padding: 70,
          concentric: n => (degree[n.id()] || 0), levelWidth: () => 2, minNodeSpacing: 60 },
        breadthfirst: { name: 'breadthfirst', animate: false, fit: true, padding: 70, directed: true, spacingFactor: 1.1 }
      };

      const cy = cytoscape({
        container, elements, minZoom: 0.3, maxZoom: 2.2, wheelSensitivity: 0.3,
        style: [
          { selector: 'node', style: {
            'background-color': e => e.data('closed') ? '#6cc04a' : '#cccccc',
            'background-image': e => e.data('thumb') || 'none', 'background-fit': 'cover',
            // ring colour encodes work type; size encodes how connected it is
            'border-color': 'data(tcolor)', 'border-width': 4,
            'width': 'data(sz)', 'height': 'data(sz)',
            'label': 'data(label)', 'color': '#cfcfcf', 'font-size': '10px',
            'text-valign': 'bottom', 'text-halign': 'center', 'text-margin-y': 6,
            'text-wrap': 'wrap', 'text-max-width': '110px',
            'transition-property': 'opacity, border-width, width, height', 'transition-duration': '160ms' } },
          { selector: 'node.primary', style: { 'border-color': '#ffffff', 'border-width': 5 } },
          // External-URL targets: a distinct link node (rounded blue chip, dashed
          // border, no thumbnail) so they read as "outside the repository".
          { selector: 'node[?external]', style: {
            'shape': 'round-rectangle', 'background-color': '#3b7ddd', 'background-image': 'none',
            'border-color': '#9ec5ff', 'border-width': 1.5, 'border-style': 'dashed',
            'width': 54, 'height': 30 } },
          { selector: 'edge', style: {
            'line-color': relColor, 'width': 2.5, 'curve-style': 'bezier',
            'target-arrow-shape': 'triangle', 'target-arrow-color': relColor, 'arrow-scale': 0.85,
            'color': '#9a9a9a', 'font-size': '9px', 'text-rotation': 'autorotate',
            'text-background-color': '#181818', 'text-background-opacity': 1, 'text-background-padding': 2,
            'transition-property': 'opacity', 'transition-duration': '160ms' } },
          // edge labels appear only for spotlighted/focused edges (cuts clutter)
          { selector: 'edge.show-label', style: { 'label': 'data(rl)' } },
          { selector: 'node.hidelabel', style: { 'text-opacity': 0 } },
          { selector: '.dimmed', style: { 'display': 'none' } },
          { selector: '.faded', style: { 'opacity': 0.08 } },
          { selector: 'node.faded', style: { 'text-opacity': 0 } }
        ],
        layout: COSE
      });

      const detail = document.getElementById('detail');
      const focusbar = document.getElementById('focusbar');
      let pinned = null; // the clicked/focused node, if any

      // ---- zoom-based label thinning (Obsidian feel) -------------------------
      // When zoomed out, only well-connected works keep their label; everything
      // gets its label back as you zoom in.
      function updateZoomLabels() {
        const z = cy.zoom();
        cy.nodes().forEach(n => {
          const keep = z > 0.62 || (degree[n.id()] || 0) >= 3;
          n[keep ? 'removeClass' : 'addClass']('hidelabel');
        });
      }
      cy.on('zoom', updateZoomLabels);

      // ---- hover spotlight (no relayout) -------------------------------------
      function spotlight(node) {
        cy.elements().addClass('faded');
        const nb = node.closedNeighborhood();
        nb.removeClass('faded');
        nb.edges().addClass('show-label');
      }
      function clearSpotlight() {
        cy.elements().removeClass('faded');
        cy.edges().removeClass('show-label');
      }
      cy.on('mouseover', 'node', e => { if (!pinned) spotlight(e.target); });
      cy.on('mouseout', 'node', e => { if (!pinned) clearSpotlight(); });

      // ---- click focus: ego-graph relayout + detail panel (as before) --------
      function focusNode(node) {
        const nbh = node.closedNeighborhood();
        cy.elements().addClass('dimmed'); nbh.removeClass('dimmed');
        cy.nodes().removeClass('primary'); node.addClass('primary');
        nbh.edges().addClass('show-label');
        document.getElementById('focuslabel').textContent = node.data('label');
        focusbar.style.display = 'flex';
        // lay the focused node + its relations out as a clean ego graph (focused
        // node centred, relations in a ring) so labels never collide
        nbh.layout({ name: 'concentric', concentric: n => (n.id() === node.id() ? 2 : 1),
                     levelWidth: () => 1, minNodeSpacing: 110, animate: false, fit: true, padding: 120 }).run();
        // Fit bounds to node boxes, not labels; pad generously (> a label's
        // half-width) so peripheral labels are not clipped on large ego rings.
        cy.fit(nbh, 120);
      }
      function clearFocus() {
        pinned = null;
        cy.elements().removeClass('dimmed faded primary');
        cy.edges().removeClass('show-label');
        focusbar.style.display = 'none';
        cy.layout(currentLayout()).run(); // re-spread with the active layout
        cy.fit(cy.elements().not('.dimmed'), 70);
        updateZoomLabels();
      }
      document.getElementById('focusclear').addEventListener('click', () => { clearFocus(); resetPanel(); });

      function showNode(node) {
        const d = node.data();
        let html = '';
        if (d.thumb) html += `<img src="${d.thumb}" alt="" style="width:120px;height:120px;border-radius:8px;float:right;margin:0 0 8px 10px">`;
        html += `<h1 style="font-size:16px">${d.label}</h1>`;
        const typeLabel = TYPE_LABEL[d.type] || d.type;
        if (typeLabel) html += `<div class="meta"><b>Type:</b> <span class="type-dot" style="background:${typeColor(d.type)}"></span>${typeLabel}</div>`;
        if (d.date) html += `<div class="meta"><b>Date:</b> ${d.date}</div>`;
        html += `<div class="meta"><b>Connections:</b> ${degree[d.id] || 0}</div>`;
        if (d.keywords && d.keywords.length) html += `<div class="meta"><b>Keywords:</b> ${d.keywords.join(', ')}</div>`;
        if (d.closed) html += `<div class="meta"><b>Access:</b> restricted</div>`;
        if (d.description) html += `<p class="meta" style="margin-top:8px">${d.description}</p>`;
        if (d.external) {
          html += `<div class="meta" style="margin-top:8px;word-break:break-all"><b>URL:</b> ${d.path}</div>`;
          html += `<p style="clear:both;margin:12px 0 2px"><a class="pagelink" href="${d.path}" target="_blank" rel="noopener noreferrer">&#8599; Open link</a></p>`;
        } else {
          html += `<p style="clear:both;margin:12px 0 2px"><a class="pagelink" href="${d.path}">&#8599; View this work's page</a></p>`;
        }
        const edges = node.connectedEdges();
        if (edges.length) {
          html += `<div class="legend" style="border:0;padding-top:12px"><h2>Relationships</h2>`;
          edges.forEach(ed => {
            const out = ed.source().id() === d.id;
            const other = out ? ed.target().data('label') : ed.source().data('label');
            const verb = out ? relLabelOf(ed.data('rel')) : relInverseOf(ed.data('rel'));
            html += `<div class="meta" style="margin:6px 0"><span class="rel-name" style="color:${relColor(ed)}">${verb}</span> &rarr; ${other}</div>`;
          });
          html += `</div>`;
        }
        html += `<p style="margin-top:14px"><a class="reset">&larr; clear</a></p>`;
        detail.innerHTML = html;
        detail.querySelector('.reset').addEventListener('click', () => { resetPanel(); clearFocus(); });
      }
      function showLink(edge) {
        const r = edge.data('rel');
        let html = `<h1 style="font-size:16px">Relationship</h1>`;
        html += `<div class="meta" style="margin:8px 0;font-size:14px"><b>${edge.source().data('label')}</b> `
              + `<span class="rel-name" style="color:${relColor(edge)}">${relLabelOf(r)}</span> <b>${edge.target().data('label')}</b></div>`;
        html += `<span class="pill">relationship</span>`;
        html += `<div class="datacite" style="margin-top:6px">relation_type: ${r} &middot; DataCite ${(REL[r] || {}).dc || ''}</div>`;
        if (edge.data('note')) html += `<div class="narr">${edge.data('note')}</div><div class="datacite" style="margin-top:4px">note &mdash; the curatorial "why"</div>`;
        html += `<p style="margin-top:14px"><a class="reset">&larr; back</a></p>`;
        detail.innerHTML = html;
        detail.querySelector('.reset').addEventListener('click', resetPanel);
      }
      function resetPanel() {
        detail.innerHTML = `<p class="hint">Hover a <b>node</b> to spotlight its connections; click it to focus and see details.
          Click a <b>line</b> for the relationship and its curatorial note.</p>`;
      }

      cy.on('tap', 'node', e => { pinned = e.target; clearSpotlight(); showNode(e.target); focusNode(e.target); });
      cy.on('tap', 'edge', e => showLink(e.target));
      cy.on('tap', e => { if (e.target === cy) { resetPanel(); clearFocus(); } });

      // ---- relationship-type filter (clickable legend) -----------------------
      function applyRelFilter() {
        cy.edges().forEach(e => { e.style('display', hiddenRels.has(e.data('rel')) ? 'none' : 'element'); });
      }
      function toggleRel(row) {
        const k = row.dataset.rel;
        if (hiddenRels.has(k)) { hiddenRels.delete(k); row.classList.remove('off'); }
        else { hiddenRels.add(k); row.classList.add('off'); }
        applyRelFilter();
      }
      legendEl.querySelectorAll('.filterable').forEach(row => {
        row.addEventListener('click', () => toggleRel(row));
        row.addEventListener('keydown', ev => { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); toggleRel(row); } });
      });

      // ---- layout switch -----------------------------------------------------
      let activeLayout = 'cose';
      function currentLayout() { return LAYOUTS[activeLayout]; }
      function runLayout(name) {
        activeLayout = LAYOUTS[name] ? name : 'cose';
        document.querySelectorAll('#layoutswitch button').forEach(b => {
          b.setAttribute('aria-pressed', String(b.dataset.layout === activeLayout));
        });
        if (pinned) { clearFocus(); resetPanel(); }
        cy.layout(currentLayout()).run();
        cy.fit(cy.elements(), 70);
        updateZoomLabels();
      }
      document.querySelectorAll('#layoutswitch button').forEach(b => {
        b.addEventListener('click', () => runLayout(b.dataset.layout));
      });

      // ---- node search -------------------------------------------------------
      const searchInput = document.getElementById('node-search');
      if (searchInput) {
        searchInput.addEventListener('input', () => {
          const q = searchInput.value.trim().toLowerCase();
          if (pinned) return; // don't fight an active focus
          if (!q) { cy.nodes().removeClass('faded hidelabel'); updateZoomLabels(); return; }
          cy.nodes().forEach(n => {
            const hit = (n.data('label') || '').toLowerCase().includes(q);
            n[hit ? 'removeClass' : 'addClass']('faded');
            if (hit) n.removeClass('hidelabel');
          });
        });
        searchInput.addEventListener('keydown', ev => {
          if (ev.key !== 'Enter') return;
          const q = searchInput.value.trim().toLowerCase();
          if (!q) return;
          const match = cy.nodes().filter(n => (n.data('label') || '').toLowerCase().includes(q))[0];
          if (match) { cy.nodes().removeClass('faded'); pinned = match; showNode(match); focusNode(match); }
        });
      }

      cy.ready(() => {
        cy.resize();
        if (FOCUS && cy.getElementById(FOCUS).nonempty()) {
          const n = cy.getElementById(FOCUS); pinned = n; showNode(n); focusNode(n);
        } else {
          cy.fit(cy.elements(), 70);
          updateZoomLabels();
        }
      });
    }

    if (G.nodes.length === 0) { /* leave the #empty message visible */ }
    else { buildGraph(); }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
