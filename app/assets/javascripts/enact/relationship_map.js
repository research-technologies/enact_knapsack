// Behaviour for the standalone Enact relationship-map page
// (app/views/enact/relationship_map/show.html.erb). The page renders with
// `layout: false` and pulls this in with its own `javascript_include_tag`.
// Server data (relation-type metadata, the node/link graph, and the optional
// focus id) is handed over through a `<script type="application/json">` data
// island so this file stays a static, cacheable asset. Precompiled in
// config/initializers/relationship_map_assets.rb.
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

    // legend (independent of the graph)
    const legendEl = document.getElementById("rel-legend");
    Object.keys(REL).forEach(k => {
      const row = document.createElement("div"); row.className = "row";
      row.innerHTML = `<span class="swatch" style="border-color:${REL[k].color}"></span>`
        + `<span>${REL[k].label} <span class="datacite">${REL[k].dc}</span></span>`;
      legendEl.appendChild(row);
    });

    function buildGraph(){
      const container = document.getElementById('cy');
      // Wait until the flex container has a real size; cose run in a 0x0 box
      // collapses/blank-renders. Retry on the next frame until it's measured.
      if (!container.clientWidth || !container.clientHeight) { requestAnimationFrame(buildGraph); return; }
      if (!window.cytoscape) { requestAnimationFrame(buildGraph); return; }

      document.getElementById("empty").style.display = "none";
      const elements = [
        ...G.nodes.map(n => ({ data: { ...n } })), // carry all fields (thumb, type, date, keywords, description...)
        ...G.links.map((l,i) => ({ data: { id:'e'+i, source:l.source, target:l.target, rel:l.rel, note:l.note, rl:relLabelOf(l.rel) } }))
      ];

      const cy = cytoscape({
        container, elements, minZoom:0.3, maxZoom:1.4,
        style: [
          { selector:'node', style:{
            'background-color': e => e.data('closed') ? '#6cc04a' : '#cccccc',
            'background-image': e => e.data('thumb') || 'none', 'background-fit':'cover',
            'border-color':'#111', 'border-width':1.5, 'width':46, 'height':46,
            'label':'data(label)', 'color':'#cfcfcf', 'font-size':'10px',
            'text-valign':'bottom', 'text-halign':'center', 'text-margin-y':6,
            'text-wrap':'wrap', 'text-max-width':'110px' } },
          { selector:'node.primary', style:{ 'border-color':'#6cc04a', 'border-width':4, 'width':58, 'height':58 } },
          { selector:'edge', style:{
            'line-color': relColor, 'width':2.5, 'curve-style':'bezier',
            'label':'data(rl)', 'font-size':'9px', 'color':'#9a9a9a',
            'text-rotation':'autorotate', 'text-background-color':'#181818',
            'text-background-opacity':1, 'text-background-padding':2 } },
          { selector:'.dimmed', style:{ 'display':'none' } }
        ],
        layout: { name:'cose', animate:false, padding:60, nodeRepulsion: 22000, idealEdgeLength: 170, nodeOverlap: 32, componentSpacing: 150, gravity: 0.3 }
      });

      const detail = document.getElementById("detail");
      const focusbar = document.getElementById("focusbar");

      const COSE = { name:'cose', animate:false, padding:60, nodeRepulsion:22000, idealEdgeLength:170, nodeOverlap:32, componentSpacing:150, gravity:0.3 };
      function focusNode(node){
        const nbh = node.closedNeighborhood();
        cy.elements().addClass('dimmed'); nbh.removeClass('dimmed');
        cy.nodes().removeClass('primary'); node.addClass('primary');
        document.getElementById("focuslabel").textContent = node.data('label');
        focusbar.style.display = "flex";
        // lay the focused node + its relations out as a clean ego graph (focused
        // node centred, relations in a ring) so labels never collide
        nbh.layout({ name:'concentric', concentric: n => (n.id() === node.id() ? 2 : 1),
                     levelWidth: () => 1, minNodeSpacing: 90, animate:false, fit:true, padding:100 }).run();
      }
      function clearFocus(){
        cy.elements().removeClass('dimmed'); cy.nodes().removeClass('primary');
        focusbar.style.display = "none";
        cy.layout(COSE).run(); // re-spread the full graph
      }
      document.getElementById("focusclear").addEventListener("click", () => { clearFocus(); resetPanel(); });

      function showNode(node){
        const d = node.data();
        let html = '';
        if (d.thumb) html += `<img src="${d.thumb}" alt="" style="width:120px;height:120px;border-radius:8px;float:right;margin:0 0 8px 10px">`;
        html += `<h1 style="font-size:16px">${d.label}</h1>`;
        if (d.type) html += `<div class="meta"><b>Type:</b> ${d.type}</div>`;
        if (d.date) html += `<div class="meta"><b>Date:</b> ${d.date}</div>`;
        if (d.keywords && d.keywords.length) html += `<div class="meta"><b>Keywords:</b> ${d.keywords.join(', ')}</div>`;
        if (d.closed) html += `<div class="meta"><b>Access:</b> restricted</div>`;
        if (d.description) html += `<p class="meta" style="margin-top:8px">${d.description}</p>`;
        html += `<p style="clear:both;margin:12px 0 2px"><a class="pagelink" href="${d.path}">&#8599; View this work's page</a></p>`;
        const edges = node.connectedEdges();
        if (edges.length){
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
        detail.querySelector(".reset").addEventListener("click", () => { resetPanel(); clearFocus(); });
      }
      function showLink(edge){
        const r = edge.data('rel');
        let html = `<h1 style="font-size:16px">Relationship</h1>`;
        html += `<div class="meta" style="margin:8px 0;font-size:14px"><b>${edge.source().data('label')}</b> `
              + `<span class="rel-name" style="color:${relColor(edge)}">${relLabelOf(r)}</span> <b>${edge.target().data('label')}</b></div>`;
        html += `<span class="pill">relationship</span>`;
        html += `<div class="datacite" style="margin-top:6px">relation_type: ${r} &middot; DataCite ${(REL[r]||{}).dc||''}</div>`;
        if (edge.data('note')) html += `<div class="narr">${edge.data('note')}</div><div class="datacite" style="margin-top:4px">note &mdash; the curatorial "why"</div>`;
        html += `<p style="margin-top:14px"><a class="reset">&larr; back</a></p>`;
        detail.innerHTML = html;
        detail.querySelector(".reset").addEventListener("click", resetPanel);
      }
      function resetPanel(){
        detail.innerHTML = `<p class="hint">Click a <b>node</b> to see how it relates to everything else (others hide).
          Click a <b>line</b> for the relationship and its curatorial note.</p>`;
      }

      cy.on('tap', 'node', e => { showNode(e.target); focusNode(e.target); });
      cy.on('tap', 'edge', e => showLink(e.target));
      cy.on('tap', e => { if (e.target === cy) { resetPanel(); clearFocus(); } });

      cy.ready(() => {
        cy.resize();
        if (FOCUS && cy.getElementById(FOCUS).nonempty()) {
          const n = cy.getElementById(FOCUS); showNode(n); focusNode(n);
        } else {
          cy.fit(cy.elements(), 50);
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
