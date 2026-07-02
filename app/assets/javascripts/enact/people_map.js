// Behaviour for the standalone Enact "research network" people map
// (app/views/enact/people_map/show.html.erb). The page renders with
// `layout: false` and pulls this in with its own `javascript_include_tag`.
// Server data (institutions, contributor nodes, shared-work links) is handed
// over through a `<script type="application/json">` data island so this file
// stays a static, cacheable asset. Precompiled in
// config/initializers/people_map_assets.rb.
//
// Knapsack-local custom code (not a Hyrax override), ported from the design
// prototype (claude.ai artifact aff512de) that the team is reacting to. Same
// interaction vocabulary as the work relationship map:
//   - nodes are people/organisations, sized by how many collaborators they have;
//   - colour encodes institution; the legend filters institutions on/off;
//   - hovering spotlights a person and their collaborators (edge weights show);
//   - labels thin out when zoomed out and sharpen as you zoom in;
//   - clicking a person pins the detail panel; clicking a line lists the shared
//     works; layout switches between force/radial/tree and search jumps to a person.
(function(){
  const D = JSON.parse(document.getElementById('people-data').textContent);
  const INST = {}; D.institutions.forEach(i => INST[i.key]=i);

  // Header spectrum: one band per institution present, in legend order.
  const spectrum = document.getElementById('spectrum');
  if (spectrum) D.institutions.forEach(it => {
    const s = document.createElement('span'); s.style.background = it.color; spectrum.appendChild(s);
  });

  const deg = {}; D.nodes.forEach(n=>deg[n.id]=0);
  D.links.forEach(l=>{deg[l.source]++; deg[l.target]++;});
  const sizeFor = id => 26 + (deg[id]||0)*3.2;

  const elements = [
    ...D.nodes.map(n=>({data:{...n, sz:sizeFor(n.id), color:(INST[n.inst]||{}).color||n.instColor||'#9aa2ad', deg:deg[n.id]||0}})),
    ...D.links.map((l,i)=>({data:{id:'e'+i, source:l.source, target:l.target, weight:l.weight, works:l.works, w:1+l.weight*1.6}}))
  ];

  const legend=document.getElementById('legend');
  const hidden=new Set();
  D.institutions.forEach(it=>{
    const row=document.createElement('div'); row.className='lrow'; row.dataset.inst=it.key;
    row.setAttribute('role','checkbox'); row.setAttribute('aria-checked','true'); row.tabIndex=0;
    row.innerHTML=`<span class="lcheck" aria-hidden="true"></span><span class="dot" style="background:${it.color}"></span><span>${it.label}</span>`;
    legend.appendChild(row);
  });

  const cy = cytoscape({
    container:document.getElementById('cy'), elements, minZoom:0.3, maxZoom:2.4, wheelSensitivity:0.3,
    style:[
      {selector:'node', style:{
        'background-color':'data(color)','width':'data(sz)','height':'data(sz)',
        'border-color':'#0e1014','border-width':1.5,
        'label':'data(label)','color':'#cfd5de','font-size':10,'font-family':'system-ui,sans-serif',
        'text-valign':'bottom','text-halign':'center','text-margin-y':5,'text-wrap':'wrap','text-max-width':110,
        'transition-property':'opacity','transition-duration':'150ms'}},
      {selector:'node[agent_type = "organization"]', style:{'shape':'round-rectangle','width':52,'height':30}},
      {selector:'node.primary', style:{'border-color':'#ffffff','border-width':3}},
      {selector:'edge', style:{'line-color':'#5b6270','width':'data(w)','curve-style':'bezier','opacity':0.55,
        'font-size':9,'color':'#c7ccd4','text-background-color':'#14161a','text-background-opacity':1,'text-background-padding':2,
        'transition-property':'opacity','transition-duration':'150ms'}},
      {selector:'edge.show-label', style:{'label':'data(weight)','line-color':'#8a93a3','opacity':0.95}},
      {selector:'node.hidelabel', style:{'text-opacity':0}},
      {selector:'.faded', style:{'opacity':0.07}},
      {selector:'node.faded', style:{'text-opacity':0}}
    ]
  });

  const LAYOUTS={
    cose:{name:'cose',animate:false,fit:true,padding:70,nodeRepulsion:45000,idealEdgeLength:150,nodeOverlap:36,componentSpacing:170,gravity:0.28},
    concentric:{name:'concentric',animate:false,fit:true,padding:60,concentric:n=>n.data('deg'),levelWidth:()=>2,minNodeSpacing:40},
    breadthfirst:{name:'breadthfirst',animate:false,fit:true,padding:60,spacingFactor:1.05}
  };
  let activeLayout='cose', pinned=null;
  function updateZoom(){const z=cy.zoom(); cy.nodes().forEach(n=>{const keep=z>0.6||(n.data('deg')||0)>=4; n[keep?'removeClass':'addClass']('hidelabel');});}
  cy.on('zoom',updateZoom);

  function spotlight(n){cy.elements().addClass('faded'); const nb=n.closedNeighborhood(); nb.removeClass('faded'); nb.edges().addClass('show-label');}
  function clearSpot(){cy.elements().removeClass('faded'); cy.edges().removeClass('show-label');}
  cy.on('mouseover','node',e=>{if(!pinned)spotlight(e.target);});
  cy.on('mouseout','node',e=>{if(!pinned)clearSpot();});

  const D_ = document.getElementById('detail');
  function esc(s){return String(s==null?'':s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
  function nameOf(id){const n=D.nodes.find(x=>x.id===id); return n?n.label:id;}
  function showPerson(n){
    const d=n.data(), it=INST[d.inst]||{};
    let h=`<h4>${esc(d.label)}</h4><div class="sub"><span class="dot" style="background:${it.color||d.instColor}"></span>${esc(it.label||d.instLabel||'')}${d.agent_type==='organization'?' &middot; organisation':''}</div>`;
    if(d.orcid) h+=`<div class="row"><b class="orcid">ORCID</b> ${esc(d.orcid)}</div>`;
    h+=`<div class="row"><b>${d.works}</b> work${d.works===1?'':'s'} &middot; <b>${d.deg}</b> collaborator${d.deg===1?'':'s'}</div>`;
    if(d.roles&&d.roles.length){h+=`<div class="row" style="margin-top:10px">`; d.roles.forEach(r=>h+=`<span class="badge">${esc(r)}</span>`); h+=`</div>`;}
    h+=`<a class="profilelink" href="${esc(d.path||'#')}">&#8599; View full profile</a>`;
    D_.innerHTML=h;
  }
  function showEdge(e){
    const a=nameOf(e.data('source')), b=nameOf(e.data('target')), works=e.data('works')||[];
    let h=`<h4 style="font-size:16px">${esc(a)} <span style="color:var(--muted)">+</span> ${esc(b)}</h4>`;
    h+=`<div class="row"><b>${works.length}</b> shared work${works.length===1?'':'s'}</div><ul class="worklist">`;
    works.forEach(w=>h+=`<li>${esc(w)}</li>`); h+=`</ul>`;
    D_.innerHTML=h;
  }
  function reset(){D_.innerHTML='<p class="ph">Hover or click a person, or a connecting line.</p>';}
  cy.on('tap','node',e=>{pinned=e.target; clearSpot(); spotlight(e.target); cy.nodes().removeClass('primary'); e.target.addClass('primary'); showPerson(e.target);});
  cy.on('tap','edge',e=>{showEdge(e.target);});
  cy.on('tap',e=>{if(e.target===cy){pinned=null; clearSpot(); cy.nodes().removeClass('primary'); reset();}});

  function applyFilter(){
    cy.nodes().forEach(n=>{ if(hidden.has(n.data('inst'))){ n.style('display','none'); } else { n.removeStyle('display'); } });
    cy.edges().forEach(e=>{
      const hide=hidden.has(cy.getElementById(e.data('source')).data('inst'))||hidden.has(cy.getElementById(e.data('target')).data('inst'));
      if(hide){ e.style('display','none'); } else { e.removeStyle('display'); }
    });
  }
  legend.querySelectorAll('.lrow').forEach(row=>{
    const t=()=>{const k=row.dataset.inst; if(hidden.has(k)){hidden.delete(k);row.classList.remove('off');}else{hidden.add(k);row.classList.add('off');} row.setAttribute('aria-checked',String(!hidden.has(k))); applyFilter();};
    row.addEventListener('click',t);
    row.addEventListener('keydown',ev=>{if(ev.key==='Enter'||ev.key===' '){ev.preventDefault();t();}});
  });

  document.querySelectorAll('.lswitch button').forEach(b=>b.addEventListener('click',()=>{
    activeLayout=LAYOUTS[b.dataset.layout]?b.dataset.layout:'cose';
    document.querySelectorAll('.lswitch button').forEach(x=>x.setAttribute('aria-pressed',String(x.dataset.layout===activeLayout)));
    pinned=null; clearSpot(); cy.nodes().removeClass('primary'); reset();
    cy.layout(LAYOUTS[activeLayout]).run(); cy.fit(cy.elements(),60); updateZoom();
  }));

  const search=document.getElementById('search');
  search.addEventListener('input',()=>{const q=search.value.trim().toLowerCase(); if(pinned)return;
    if(!q){cy.nodes().removeClass('faded'); updateZoom(); return;}
    cy.nodes().forEach(n=>{const hit=(n.data('label')||'').toLowerCase().includes(q); n[hit?'removeClass':'addClass']('faded'); if(hit)n.removeClass('hidelabel');});});
  search.addEventListener('keydown',ev=>{if(ev.key!=='Enter')return; const q=search.value.trim().toLowerCase(); if(!q)return;
    const m=cy.nodes().filter(n=>(n.data('label')||'').toLowerCase().includes(q))[0];
    if(m){cy.nodes().removeClass('faded'); pinned=m; cy.nodes().removeClass('primary'); m.addClass('primary'); spotlight(m); showPerson(m); cy.animate({center:{eles:m},zoom:1.3},{duration:300});}});

  cy.ready(()=>{cy.layout(LAYOUTS.cose).run(); cy.fit(cy.elements(),60); updateZoom();});
})();
