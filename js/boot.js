/* ---------- boot ---------- */
// with a save in S: point the engine at its chapter, and make sure the place and beat it names still exist
function resume(){
  if(!S.ch||!CH[S.ch])S.ch=WORLD.chapters[0].id;
  useChapter(S.ch);
  if(!S.loc||!ST.places[S.loc])S.loc=ST.meta['start-place'];
  if(S.node&&!ST.nodes[S.node])S.node=null;
  revealFor=S.node;lastLoc=S.loc;
}
async function boot(){
  try{
    const get=async f=>{const r=await fetch('story/'+f,{cache:'no-cache'});if(!r.ok)throw new Error(f+' returned '+r.status);return r.text()};
    WORLD=parseStory(await get('world.story'),null,'world.story');CH={};
    for(const c of WORLD.chapters)if(c.file)CH[c.id]=parseStory(await get(c.file),null,c.file);
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
