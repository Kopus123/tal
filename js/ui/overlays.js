/* ============ OVERLAYS ============
   Panels that open over the game: menu, settings, log, chapters, map, title, toasts. */

/* ---------- overlays ---------- */
function overlay(html,cls=''){sfx('open');const o=document.createElement('div');o.className='ov '+cls;o.innerHTML=html;o.addEventListener('click',e=>{if(e.target===o)close(o)});$('#ovs').appendChild(o);return o}
let NB_REDRAW=null;
function close(o){stopAudio();o.remove();render();if(NB_REDRAW&&document.querySelector('#nbb'))NB_REDRAW()}
function closeTop(){const o=$('#ovs').lastElementChild;if(o)close(o)}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeTop()});
const head=t=>`<div class="ph-head"><h2>${t}</h2><button class="x" aria-label="Close">×</button></div>`;
const STATE_LABEL={new:'New word',seen:'No note yet',guess:'Your guess',sure:'You\'re sure',gram:'Grammar piece'};

function showLog(){
  const o=overlay(`<div class="panel paper">${head('기록')}<div class="ph-body" id="hb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const rows=S.log.map((e,i)=>{
    if(e.who==='narr')return`<div class="hl narr-row">${esc(e.en)}</div>`;
    const c=ST.cast[e.who]||{};const you=e.who==='you';
    if(e.heard)return`<div class="hl"><div style="min-width:0;flex:1"><div class="hn">${esc(c.n||'')}</div><div class="hk heardrow">🔊 Heard, not written down yet</div></div><button class="say" data-hi="${i}" aria-label="Hear it">▶</button></div>`;
    const face=you?'':c.look?portrait(c.look,e.ex):e.who==='sign'?'':speakerGlyph();
    return`<div class="hl ${you?'you':''}">${face?`<div class="pt sm" style="--cbg:${c.c||'#888'}">${face}</div>`:''}<div style="min-width:0;flex:1">
      <div class="hn">${esc(you?'You':e.who==='sign'?'Written':c.n||'')}</div><div class="hk">${ko(e.ko,true,false)}</div>${e.en?`<div class="en">${esc(e.en)}</div>`:''}</div>
      <button class="say" data-hi="${i}" aria-label="Hear it">▶</button></div>`}).join('');
  o.querySelector('#hb').innerHTML=rows||'<div class="empty">Nothing yet.</div>';
  o.querySelectorAll('[data-hi]').forEach(b=>b.onclick=()=>{const e=S.log[+b.dataset.hi];speak(e.ko,e.who)});
  const hb=o.querySelector('#hb');hb.scrollTop=hb.scrollHeight;
}

function menu(){
  const o=overlay(`<div class="panel">${head('메뉴')}<div class="ph-body"><div class="menulist">
    <button class="mi" id="mHint"><span class="mic">💡</span><span><b>Think</b><small>A nudge in the right direction</small></span></button>
    <div class="hintbox" id="hintbox" hidden></div>
    <button class="mi" id="mLog"><span class="mic">💬</span><span><b>What was said</b><small>Scroll back through every line</small></span></button>
    <button class="mi" id="mMap"><span class="mic">🗺️</span><span><b>Village map</b><small>Places you've been</small></span></button>
    <button class="mi" id="mCh"><span class="mic">📖</span><span><b>Chapters</b><small>Continue, replay</small></span></button>
    ${S.set.dev?`<button class="mi" id="mJump"><span class="mic">⏩</span><span><b>Jump ahead</b><small>Playtest: skip to a point in the story</small></span></button><div class="jumplist" id="jumplist" hidden></div>`:''}
    <button class="mi" id="mSet"><span class="mic"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg></span><span><b>Settings</b><small>Voice, text size, sounds</small></span></button>
  </div></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  o.querySelector('#mHint').onclick=()=>{sfx('tap');const h=ST.hints.find(x=>cond(x.c));const b=o.querySelector('#hintbox');b.textContent=h?h.t:'Look around.';b.hidden=false};
  o.querySelector('#mLog').onclick=()=>{o.remove();showLog()};
  o.querySelector('#mMap').onclick=()=>{o.remove();openMap()};
  o.querySelector('#mCh').onclick=()=>{o.remove();chapterList()};
  o.querySelector('#mSet').onclick=()=>{o.remove();settings()};
  const mj=o.querySelector('#mJump');if(mj)mj.onclick=async()=>{sfx('tap');const box=o.querySelector('#jumplist');box.hidden=false;box.textContent='Loading…';
    try{const r=await fetch('tests/ch1.route',{cache:'no-cache'});const marks=(await r.text()).split(/\r?\n/).filter(l=>l.startsWith('#@')).map(l=>l.slice(2).trim());
      box.innerHTML=marks.map((m,i)=>`<button class="btn-ink jumpitem" data-jump="${i}"><span>${i+1}</span>${esc(m)}</button>`).join('')+'<div class="empty">Plays the story up to there in a few seconds. Your notebook stays as it is.</div>';
      box.querySelectorAll('[data-jump]').forEach(b=>b.onclick=()=>{o.remove();jumpTo(marks[+b.dataset.jump])});
    }catch(e){box.textContent='Could not load the jump list.'}};
}

// playtest: replay the solution route up to a checkpoint (js/autotest.js does the playing)
function jumpTo(label){
  document.querySelectorAll('.title').forEach(t=>t.remove());
  const go=()=>window.TAL_TEST.jump('ch1',label);
  if(window.TAL_TEST){go();return}
  const sc=document.createElement('script');sc.src='js/autotest.js';sc.onload=go;sc.onerror=()=>toast('Could not load the playtest tools.');document.body.appendChild(sc);
}
function settings(){
  const o=overlay(`<div class="panel">${head('설정')}<div class="ph-body" id="stb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let confirmReset=false;
  const seg=(k,opts)=>`<span class="seg">${opts.map(([v,t])=>`<button data-k="${k}" data-v="${v}" class="${S.set[k]==v?'on':''}">${t}</button>`).join('')}</span>`;
  const draw=()=>{
    o.querySelector('#stb').innerHTML=`
      <div class="set-row"><span>Read lines aloud automatically</span>${seg('auto',[[1,'On'],[0,'Off']])}</div>
      <div class="set-row"><span>Voice speed</span>${seg('slow',[[0,'Normal'],[1,'Slow']])}</div>
      <div class="set-row"><span>Korean text size</span>${seg('size',[[0,'Small'],[1,'Medium'],[2,'Large']])}</div>
      <div class="set-row"><span>Things glow when named</span>${seg('glow',[[1,'On'],[0,'Off']])}</div>
      <div class="set-row"><span>Sound effects and vibration</span>${seg('sound',[[1,'On'],[0,'Off']])}</div>
      <div class="set-row"><span>Playtest tools (skip button)</span>${seg('dev',[[1,'On'],[0,'Off']])}</div>
      <button class="btn-ink" id="tv">▶ Test voice</button>
      ${S.set.dev?`<div class="empty">Tracking ${Object.keys(S.m).length} words · save format ${S.v}</div><button class="btn-ink" id="cps">Copy save data</button>`:''}
      <button class="btn-ink" id="rs" style="color:#e59a87">${confirmReset?'Tap again to erase all progress':'Start over'}</button>`;
    o.querySelectorAll('[data-k]').forEach(b=>b.onclick=()=>{S.set[b.dataset.k]=+b.dataset.v;save();sfx('tap');draw();document.documentElement.dataset.size=S.set.size});
    o.querySelector('#tv').onclick=()=>speak('{안녕하세요}!','sujin');
    const cps=o.querySelector('#cps');if(cps)cps.onclick=()=>{try{navigator.clipboard.writeText(JSON.stringify(S));toast('Save data copied.')}catch(e){toast('Could not copy.')}};
    o.querySelector('#rs').onclick=()=>{if(!confirmReset){confirmReset=true;draw()}else{S=freshKeepNotes();BACK=[];save();o.remove();title()}};
  };draw();
}

function finale(){
  S.done[S.ch]=1;stash();save();
  const cont=nextChapter();
  if(cont&&cont.cont&&chReady(cont.id)){startChapter(cont.id,true);return} // same chapter, the story just keeps going
  const vocab=Object.keys(S.w).filter(id=>W[id]&&!W[id].g);const n=s=>vocab.filter(id=>status(id)===s).length;
  const nx=nextChapter();
  const nextBit=!nx?'':chReady(nx.id)?`<button class="btn primary" id="nextch">Start ${esc(nx.t)}</button>`:`<div class="en" style="text-align:center">${esc(nx.t)} is coming soon.</div>`;
  const o=overlay(`<div class="panel paper">${head(esc(ST.meta['end-title']||''))}<div class="ph-body">
    <div class="narr">${esc(ST.meta['end-text']||'')}</div>
    <div><div class="stat"><span>Words you're sure of</span><b>${n('sure')}</b></div><div class="stat"><span>Words you have a guess for</span><b>${n('guess')}</b></div><div class="stat"><span>Words with no note yet</span><b>${n('new')+n('seen')}</b></div></div>
    ${nextBit}<button class="btn" id="fin" style="justify-content:center">Keep exploring</button></div></div>`,'center');
  o.querySelector('.x').onclick=()=>close(o);o.querySelector('#fin').onclick=()=>close(o);
  const nb=o.querySelector('#nextch');if(nb)nb.onclick=()=>{o.remove();startChapter(nx.id,true)};
}

function chapterList(){
  const o=overlay(`<div class="panel">${head('목차')}<div class="ph-body" id="clb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let confirmId=null;
  const leave=()=>{o.remove();const t=document.querySelector('.title');if(t)t.remove()};
  const restartGroup=hid=>{const parts=groupParts(chInfo(hid));leave();
    parts.forEach(p=>{if(p.id!==S.ch)delete S.prog[p.id];delete S.done[p.id]});
    startChapter(hid,true);parts.slice(1).forEach(p=>delete S.prog[p.id]);save()};
  const draw=()=>{
    o.querySelector('#clb').innerHTML=WORLD.chapters.filter(c=>!c.cont).map(c=>{
      const parts=groupParts(c).filter(p=>chReady(p.id));
      const ready=parts.length>0,open=ready&&chUnlocked(c.id);
      const done=ready&&!!S.done[parts[parts.length-1].id],started=parts.some(p=>chStarted(p.id));
      const cur=[...parts].reverse().find(p=>chStarted(p.id)&&!S.done[p.id]);
      const state=!ready?'Coming soon':!open?'Locked':done?'Finished':started?'In progress':'New';
      let b='';
      if(open){
        if(cur&&!done)b+=`<button class="btn-ink" data-go="${cur.id}">Continue</button>`;
        if(!started&&!done)b+=`<button class="btn-ink" data-new="${c.id}">Start</button>`;
        if(started||done)b+=confirmId===c.id?`<button class="btn-ink" data-new="${c.id}" style="color:#e59a87">Tap again to start over</button>`:`<button class="btn-ink" data-ask="${c.id}">${done?'Replay':'Start over'}</button>`;
      }
      return `<div class="chrow ${open?'':'locked'} ${groupHead(S.ch).id===c.id?'cur':''}"><div class="chn"><b>${esc(c.t)}</b><span>${esc(open||done?c.sub:'?')}</span></div><div class="chs">${state}</div><div class="chb">${b}</div></div>`;
    }).join('')+`<div class="empty">Your notebook and map carry over between chapters. Replaying a chapter starts it from the beginning.</div>`;
    o.querySelectorAll('[data-go]').forEach(x=>x.onclick=()=>{leave();startChapter(x.dataset.go,false)});
    o.querySelectorAll('[data-new]').forEach(x=>x.onclick=()=>restartGroup(x.dataset.new));
    o.querySelectorAll('[data-ask]').forEach(x=>x.onclick=()=>{confirmId=x.dataset.ask;draw()});
  };
  draw();
}

/* ---------- village map ---------- */
function openMap(){
  const ok=canTravel();
  const o=overlay(`<div class="panel paper">${head('지도')}<div class="ph-body" style="padding:10px 12px 16px"><div class="map" id="mapv"></div><div class="en" style="text-align:center">${
    ok?'Tap a place you have been to go there.':S.node?'Finish what you are doing first, then you can travel.':'You can\'t walk anywhere from here.'}</div></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let h=`<svg viewBox="0 0 400 520" class="mapart" aria-hidden="true">${artMap()}</svg>`;
  ST.map.filter(p=>ST.places[p.p]).forEach(p=>{
    const pl=ST.places[p.p],here=S.loc===p.p;
    if(!S.known[p.p]){h+=`<div class="pin unk" style="left:${p.x}%;top:${p.y}%"><i></i><b>?</b></div>`;return}
    h+=`<button class="pin ${here?'here':''}" data-pin="${p.p}" style="left:${p.x}%;top:${p.y}%"><i></i><b>${esc(pl.name)}</b>${here?'<span class="seal w" data-w="여기">여기</span>':''}</button>`;
  });
  o.querySelector('#mapv').innerHTML=h;
  o.querySelectorAll('[data-pin]').forEach(b=>b.onclick=()=>{
    const id=b.dataset.pin;if(id===S.loc){close(o);return}
    if(!ok){sfx('wrong');toast(S.node?'Finish what you are doing first.':'You can\'t walk there from here.');return}
    if(ST.places[id].travel==='no'){sfx('wrong');toast('You can\'t walk there. You\'ll need another way.');return}
    o.remove();sfx('page');enter(id);
  });
}

/* one copy of each message; tapping again just keeps it up longer */
const TOASTS={};
function toast(h,ms=2600){
  let t=TOASTS[h];
  if(t){clearTimeout(t._tm);t.style.animation='none';void t.offsetWidth;t.style.animation=''}
  else{t=document.createElement('div');t.className='toast';t.innerHTML=h;$('#toasts').appendChild(t);TOASTS[h]=t}
  t._tm=setTimeout(()=>{t.remove();delete TOASTS[h]},ms);
}

function title(){
  const m=ST.meta,has=!!S.F.started||Object.keys(S.prog).length>0;
  const o=document.createElement('div');o.className='title';
  o.innerHTML=`<div class="art"><svg viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice">${artGateInner(false)}</svg><div class="amb">${ambientHTML('motes')}</div></div>
    <h1>${esc(m.title||'')}</h1><div class="vil">${esc(m.village||'')}</div><p>${esc(m.blurb||'')}</p>
    <div class="acts">${has?`<button class="btn primary" id="tc">Continue · ${esc(groupHead(S.ch).t||'')}</button><button class="btn" id="tl">Chapters</button>`:''}<button class="btn ${has?'':'primary'}" id="tn">${has?'New game':'Start'}</button></div>
    <div class="fine">Turn your sound on.</div>`;
  document.body.appendChild(o);
  if(has){
    o.querySelector('#tc').onclick=()=>{sfx('page');o.remove();if(!S.F.started)startChapter(S.ch,true);else{lastLoc=null;render()}};
    o.querySelector('#tl').onclick=()=>chapterList();
  }
  let sure=!has;const tn=o.querySelector('#tn');
  tn.onclick=()=>{
    if(!sure){sure=true;tn.textContent='Tap again to erase all progress';tn.style.color='#e59a87';return}
    sfx('page');S=freshKeepNotes();BACK=[];o.remove();startChapter(WORLD.chapters[0].id,true);
  };
}
