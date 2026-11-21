/* ---------- boot ---------- */
// with a save in S: point the engine at its chapter, and make sure the place and beat it names still exist
function resume(){
  if(!S.ch||!CH[S.ch])S.ch=WORLD.chapters[0].id;
  // a test area never resumes: reopening the game puts you back in the story (Jump ahead starts the test area fresh)
  if(chInfo(S.ch).dev){const b=S.world.g.devBack;delete S.world.g.devBack;S.ch=b&&CH[b]&&!chInfo(b).dev?b:WORLD.chapters[0].id;
    const p=S.prog[S.ch];if(p&&p.F&&p.F.started)CH_FIELDS.forEach(k=>S[k]=p[k]);else{S.loc=null;S.node=null}}
  useChapter(S.ch);
  if(!S.loc||!ST.places[S.loc])S.loc=ST.meta['start-place'];
  if(S.node&&!ST.nodes[S.node])S.node=null;
  revealFor=S.node;lastLoc=S.loc;
}
const BUILD='49';   // same number as <meta name="tal-build"> in index.html: bump both together
async function boot(){
  // an old copy of the page with new code (the browser kept the page): fetch the page fresh, once
  const pb=(document.querySelector('meta[name="tal-build"]')||{}).content;
  if(pb!==BUILD){let tried=false;try{tried=sessionStorage.getItem('tal-build')===BUILD;sessionStorage.setItem('tal-build',BUILD)}catch(_){}
    if(!tried){try{await fetch(location.pathname,{cache:'reload'})}catch(_){}location.reload();return}}
  try{
    const get=async f=>{const r=await fetch('story/'+f,{cache:'no-cache'});if(!r.ok)throw new Error(f+' returned '+r.status);return r.text()};
    WORLD=parseStory(await get('world.story'),null,'world.story');CH={};
    for(const c of WORLD.chapters)if(c.file)for(const f of c.file.split('+').map(x=>x.trim()))CH[c.id]=parseStory(await get(f),CH[c.id],f);
    for(const pf of WORLD.peopleFiles){const d=parseStory(await get('people/'+pf.file),null,pf.file);Object.assign(PEOPLE,d.people);Object.assign(PNODES,d.nodes)}indexPeople();
    W=Object.assign({},WORLD.words,...Object.values(CH).map(c=>c.words));buildNames();
    try{sessionStorage.removeItem('tal-repair')}catch(_){}
  }catch(e){
    // First failure: throw away the offline copy (an old one can mix with new files) and reload once.
    let tried=null;try{tried=sessionStorage.getItem('tal-repair')}catch(_){}
    if(!tried){
      try{sessionStorage.setItem('tal-repair','1');
        if(navigator.serviceWorker){const regs=await navigator.serviceWorker.getRegistrations();await Promise.all(regs.map(r=>r.unregister()))}
        if(window.caches){const ks=await caches.keys();await Promise.all(ks.map(k=>caches.delete(k)))}
      }catch(_){}
      location.reload();return;
    }
    $('#boot').innerHTML=`<div style="font-family:var(--f-ui);font-size:1rem;line-height:1.5;text-align:center;padding:24px;max-width:32ch">Could not load the story.<br><small style="color:var(--mist)">${esc(e&&e.message||e)}</small><br><br><button class="btn-ink" id="retry">Try again</button></div>`;
    $('#retry').onclick=()=>{try{sessionStorage.removeItem('tal-repair')}catch(_){}location.reload()};
    return;
  }
  load();resume();
  $('#boot').remove();
  $('#bNote').onclick=notebook;$('#bCase').onclick=()=>caseBoard();$('#bPhone').onclick=openPhone;$('#bMenu').onclick=menu;
  $('#locKo').onclick=openMap;$('#locSub').onclick=openMap;
  render();title();
}
boot();
if('serviceWorker' in navigator&&location.protocol==='https:'&&!/claude\.ai|claudeusercontent/.test(location.host)){
  navigator.serviceWorker.register('sw.js').catch(()=>{});
}
