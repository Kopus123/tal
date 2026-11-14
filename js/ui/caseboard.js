/* ---------- the case board: deductions (fill the blanks) + evidence ----------
   A deduction is a sentence with blanks; you fill them with words from your notebook.
   It's checked as a whole: when it's wrong you only learn that something doesn't follow. */
let pickQ=null,FILL={},ACT=0,boardTab='ded',PROOF={},PMODE=null;
// proof: either order counts
const proofOk=(q,pf)=>!q.needs||[[0,1],[1,0]].some(o=>q.needs.length===2?q.needs.every((alts,i)=>alts.includes(pf[o[i]])):q.needs.every((alts,i)=>alts.includes(pf[i])));
function proofChip(id){const e=ST.evidence[id];if(e)return `${iconSVG(e.icon)}<span>${esc(plain(e.label))}</span>`;
  const st=ST.statements[id];if(st){const nd=ST.nodes[st.node],c=ST.cast[nd.who]||{};return `<span class="pface">${c.look?portrait(c.look,nd.ex):speakerGlyph()}</span><span>${esc(plain(nd.ko).slice(0,14))}…</span>`}return esc(id)}
const normAns=s=>String(s).replace(/[\s.?!~,·]/g,'');
const owned=()=>Object.values(ST.evidence||{}).filter(e=>S.F['ev_'+e.id]);
// statements: lines people said that matter, saved by "! statement ID" in the story
const ownedSt=()=>Object.values(ST.statements||{}).filter(x=>S.F['st_'+x.id]&&ST.nodes[x.node]);
function stCard(x,attrs){const nd=ST.nodes[x.node],c=ST.cast[nd.who]||{};
  const face=c.look?portrait(c.look,nd.ex):speakerGlyph();
  return `<button ${attrs}><div class="pt sm" style="--cbg:${c.c||'#888'}">${face}</div><span><b>${ko(nd.ko,false,false)}</b><small>${esc(c.n||'')}</small></span></button>`}
// about 14 words to choose from: every blank on this chapter's board, plus a few others you've met. Typing searches everything.
function shortlist(q,filter){
  const ok=id=>W[id]&&!W[id].g&&S.w[id];
  if(filter)return Object.keys(S.w).filter(id=>ok(id)&&(id.includes(filter)||(S.w[id].note||'').toLowerCase().includes(filter.toLowerCase()))).slice(0,16);
  let h=7;for(const ch of q.id)h=(h*31+ch.charCodeAt(0))>>>0;
  const rnd=()=>{h=(h*1103515245+12345)>>>0;return h/4294967296};
  const mix=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(rnd()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
  const pool=new Set();ST.cases.filter(c=>cond(c.c)&&!S.cs[c.id]).forEach(c=>c.blanks.forEach(a=>{if(W[a])pool.add(a)})); // only cards on the board now: no spoilers
  if(q.blanks.some(b=>W[b]&&W[b].g))Object.keys(WORLD.tells).concat(['이에요','아니에요']).filter(id=>W[id]).forEach(id=>pool.add(id));
  mix(Object.keys(S.w).filter(id=>ok(id)&&W[id].p&&!pool.has(id))).slice(0,Math.max(0,16-pool.size)).forEach(x=>pool.add(x));
  return mix([...pool]);
}
// sentence with slots; filled = array of words (or null)
function dedHTML(q,mode){
  // each blank shows the English it stands for: you know what you've worked out, now say it in Korean
  let k=0;return esc(q.text).replace(TOK,(m,surf,id)=>{const i=k++;id=id||surf;
    if(mode==='solved')return `<b class="slot done">${esc(surf)}</b>`;
    const cue=`<small class="cue">${esc(meaningOf(id)||'?')}</small>`;
    if(mode==='closed')return `<span class="slot empty">${cue}</span>`;
    const f=(FILL[q.id]||[])[i];return `<button class="slot ${f?'filled':'empty'} ${i===ACT&&PMODE===null?'active':''}" data-slot="${i}">${f?esc(f):cue}</button>`});
}
// the proof picker offers four cards: what proves it (if you have it) and a couple of others
function proofOptions(q){
  const have=new Set([...owned().map(e=>e.id),...ownedSt().map(x=>x.id)]);
  const need=q.needs.map(alts=>alts.find(a=>have.has(a))).filter(Boolean);
  let h=11;for(const ch of q.id)h=(h*31+ch.charCodeAt(0))>>>0;const rnd=()=>{h=(h*1103515245+12345)>>>0;return h/4294967296};
  const mix=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(rnd()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
  const flat=new Set(q.needs.flat());
  const opts=mix([...need,...mix([...have].filter(id=>!flat.has(id))).slice(0,Math.max(2,4-need.length))]);
  return {opts,missing:need.length<q.needs.length};
}
function proofCard(id,attrs){const e=ST.evidence[id];if(e)return `<button ${attrs}>${iconSVG(e.icon)}<span><b>${ko(e.label,false,false)}</b><small>${esc(e.desc)}</small></span></button>`;
  const st=ST.statements[id];return st?stCard(st,attrs):''}
const EVGROUP=e=>e.icon==='photo'?'Photos':['letter','phone','card','ticket'].includes(e.icon)?'Papers and messages':'Things you found';
const STRIKE={}; // wrong checks per deduction: three in a row and it needs a short break
function caseBoard(tab){
  if(typeof tab==='string')boardTab=tab; // the top-bar button passes a click event, not a tab name
  const o=overlay(`<div class="panel cboard">${head('사건')}<div class="ph-body" id="cbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let filter='',miss='';
  const check=q=>{
    const sk=STRIKE[q.id]=STRIKE[q.id]||{n:0,until:0};
    if(Date.now()<sk.until){toast('Give it a moment. Look around or reread your evidence first.');return}
    const f=FILL[q.id]||[];
    if(q.blanks.some((b,i)=>!f[i])){toast('Fill in every blank first.');return}
    const pf=PROOF[q.id]||[];if(q.needs&&q.needs.some((x,i)=>!pf[i])){toast('Pin your proof first.');return}
    const wordsOk=q.blanks.every((b,i)=>b.split('/').some(a=>normAns(a)===normAns(f[i]))),pOk=proofOk(q,pf);
    if(wordsOk&&pOk){
      S.cs[q.id]=1;S.F['solved_'+q.id]=1;PMODE=null;sk.n=0;q.blanks.forEach(b=>noteUsed('{'+b+'}',true));
      q.blanks.filter(b=>WORLD.tells[b]&&!S.tl[b]).forEach(b=>{S.tl[b]=1;setTimeout(()=>toast(`New tell in your notebook: <b>${esc(b)}</b>`,4000),400)});
      save();pickQ=null;filter='';miss='';sfx('solve');buzz([20,40,20]);draw();
      if(q.final)setTimeout(()=>{close(o);finale()},900);else if(caseReadyNow())toast('Everything you know fits together.');
    }else{sfx('wrong');buzz(60);sk.n++;
      if(sk.n>=3){sk.n=0;sk.until=Date.now()+45000;miss='Too many guesses. Go look around or reread your evidence, then try again in 45 seconds.'}
      else if(sk.n===2&&q.needs)miss=wordsOk?'The words fit. The proof doesn\'t.':pOk?'The proof is right. A word is off.':'Neither the words nor the proof fit yet.';
      else miss='Something doesn\'t follow.';
      draw()}
  };
  const place=(q,word)=>{const f=FILL[q.id]=FILL[q.id]||[];f[ACT]=word;miss='';sfx('tap');
    const nxt=q.blanks.findIndex((b,i)=>!f[i]);if(nxt>=0)ACT=nxt;filter='';draw()};
  const pickHTML=q=>shortlist(q,filter).map(id=>`<button class="w ${status(id)}" data-pk="${esc(id)}" data-w="">${esc(id)}</button>`).join('')||'<span class="empty">No matching words.</span>';
  const draw=()=>{
    const cbb=o.querySelector('#cbb'),top=cbb.scrollTop;
    let h=`<div class="tabs cbtabs"><button class="tab ${boardTab==='ded'?'on':''}" data-bt="ded">Deductions</button><button class="tab ${boardTab==='ev'?'on':''}" data-bt="ev">Evidence · ${owned().length}</button><button class="tab ${boardTab==='st'?'on':''}" data-bt="st">Statements · ${ownedSt().length}</button></div>`;
    if(boardTab==='st'){
      const sts=ownedSt(),by={};sts.forEach(x=>{const w=ST.nodes[x.node].who;(by[w]=by[w]||[]).push(x)});
      h+=sts.length?Object.entries(by).map(([w,xs])=>`<div class="cbhead">${esc((ST.cast[w]||{}).n||w)}</div><div class="evlist">${xs.map(x=>stCard(x,`class="evcard stcard" data-sth="${x.id}"`)).join('')}</div>`).join('')
        :`<div class="cbnote">Nothing yet. When someone says something that matters, it's pinned here.</div>`;
    }else if(boardTab==='ev'){
      const ev=owned();
      h+=ev.length?['Things you found','Photos','Papers and messages'].map(g=>{const xs=ev.filter(e=>EVGROUP(e)===g);
          return xs.length?`<div class="cbhead">${g}</div><div class="evlist">${xs.map(e=>`<button class="evcard" data-ev="${e.id}">${iconSVG(e.icon)}<span><b>${ko(e.label,false,false)}</b><small>${esc(e.desc)}</small></span></button>`).join('')}</div>`:''}).join('')
        :`<div class="cbnote">Nothing yet. Things you find that matter will be pinned here.</div>`;
    }else{
      const qs=ST.cases.filter(q=>cond(q.c));
      h+=qs.length?`<div class="cbnote">Each card is something you've worked out. The English under each blank is what goes there: say it in Korean. Some cards also need proof pinned to them.</div>`
        :`<div class="cbnote">Nothing to work out yet. Look around and see what you can find.</div>`;
      h+=qs.map(q=>{
        const lock=STRIKE[q.id]&&Date.now()<STRIKE[q.id].until;
        if(S.cs[q.id])return`<div class="q solved"><span class="stamp">해결</span><div class="ded">${dedHTML(q,'solved')}</div>${q.needs?`<div class="proofrow done">${(PROOF[q.id]||[]).filter(Boolean).map(id=>`<span class="pslot filled">${proofChip(id)}</span>`).join('')}</div>`:''}<div class="why">${esc(q.why)}</div></div>`;
        if(pickQ!==q.id)return`<div class="q closed" data-open="${q.id}" role="button" tabindex="0"><div class="ded">${dedHTML(q,'closed')}</div><div class="qfoot">${q.needs?`📌 Needs ${q.needs.length} pieces of proof · `:''}${lock?'Taking a break from this one…':'Tap to work it out'}</div></div>`;
        const pf=PROOF[q.id]||[];
        const proofRow=q.needs?`<div class="proofrow"><span class="plabel">Proof</span>${q.needs.map((x,i)=>`<button class="pslot ${pf[i]?'filled':''} ${PMODE===i?'active':''}" data-ps="${i}">${pf[i]?proofChip(pf[i]):`📌 ${esc(x.hint||'Pin proof')}`}</button>`).join('')}</div>`:'';
        if(PMODE!==null&&q.needs){const po=proofOptions(q);
          return`<div class="q open"><div class="ded">${dedHTML(q,'open')}</div>${proofRow}<div class="label">${q.needs[PMODE]&&q.needs[PMODE].hint?`Pick: ${esc(q.needs[PMODE].hint)}`:'Which of these proves it?'}</div>${po.missing?'<div class="why">You might not have found everything you need for this one yet.</div>':''}
            <div class="evlist">${po.opts.map(id=>proofCard(id,`class="evcard ${pf.includes(id)?'sel':''}" data-pp="${id}"`)).join('')}</div>
            <div class="row"><button class="btn-ink" data-pcancel>Back to the words</button></div></div>`}
        return`<div class="q open"><div class="ded">${dedHTML(q,'open')}</div>${proofRow}
          <form class="typeans" id="ta"><input id="ti" lang="ko" autocomplete="off" placeholder="Type to find a word" value="${esc(filter)}"></form>
          <div class="pick">${pickHTML(q)}</div>
          ${miss?`<div class="miss">${esc(miss)}</div>`:''}
          <div class="row"><button class="btn-ink" data-clear="${q.id}">Clear</button><button class="btn-ink primary" data-check="${q.id}" ${lock?'disabled':''}>Check</button></div></div>`;
      }).join('');
    }
    cbb.innerHTML=h;cbb.scrollTop=top;
    o.querySelectorAll('[data-bt]').forEach(b=>b.onclick=()=>{boardTab=b.dataset.bt;sfx('tap');draw()});
    o.querySelectorAll('[data-ev]').forEach(b=>b.onclick=()=>evidenceSheet(b.dataset.ev));
    o.querySelectorAll('[data-sth]').forEach(b=>b.onclick=()=>{const nd=ST.nodes[ST.statements[b.dataset.sth].node];speak(nd.ko,nd.who)});
    o.querySelectorAll('[data-open]').forEach(b=>b.onclick=()=>{sfx('tap');pickQ=b.dataset.open;PMODE=null;FILL[pickQ]=FILL[pickQ]||[];ACT=Math.max(0,ST.cases.find(x=>x.id===pickQ).blanks.findIndex((x,i)=>!FILL[pickQ][i]));filter='';miss='';draw()});
    const q=ST.cases.find(x=>x.id===pickQ);if(!q||boardTab!=='ded')return;
    o.querySelectorAll('[data-slot]').forEach(b=>b.onclick=()=>{ACT=+b.dataset.slot;PMODE=null;sfx('tap');draw()});
    o.querySelectorAll('[data-ps]').forEach(b=>b.onclick=()=>{const i=+b.dataset.ps;PMODE=PMODE===i?null:i;miss='';sfx('tap');draw()});
    o.querySelectorAll('[data-pp]').forEach(b=>b.onclick=()=>{const pf=PROOF[q.id]=PROOF[q.id]||[];const id=b.dataset.pp;
      const other=pf.indexOf(id);if(other>=0&&other!==PMODE)pf[other]=null;pf[PMODE]=id;
      const nxt=q.needs.findIndex((x,i)=>!pf[i]);PMODE=nxt>=0?nxt:null;sfx('tap');draw()});
    const pc=o.querySelector('[data-pcancel]');if(pc)pc.onclick=()=>{PMODE=null;draw()};
    o.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>place(q,b.dataset.pk));
    o.querySelectorAll('[data-clear]').forEach(b=>b.onclick=()=>{FILL[q.id]=[];PROOF[q.id]=[];PMODE=null;ACT=0;miss='';draw()});
    o.querySelectorAll('[data-check]').forEach(b=>b.onclick=()=>check(q));
    const ti=o.querySelector('#ti');if(ti){ti.oninput=e=>{filter=e.target.value.trim();
      const pk=o.querySelector('.pick');pk.innerHTML=pickHTML(q);pk.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>place(q,b.dataset.pk))}}
    const ta=o.querySelector('#ta');if(ta)ta.onsubmit=e=>{e.preventDefault();const v=normAns(o.querySelector('#ti').value);if(!v)return;
      const ids=Object.keys(W);
      const hit=ids.find(id=>normAns(id)===v)||ids.find(id=>jamoDist(normAns(id),v)<=1);
      if(!hit){toast('That isn\'t a word you\'ve met yet.');return}
      if(normAns(hit)!==v)toast('Close! It\'s spelled <b>'+esc(hit)+'</b>',4000);
      place(q,hit)};
  };
  draw();
}
function evidenceSheet(id){
  const e=ST.evidence[id];if(!e)return;
  const o=overlay(`<div class="panel paper">${head('증거')}<div class="ph-body">
    <div class="wordhead">${iconSVG(e.icon,'bigicon')}<div style="display:flex;flex-direction:column;gap:6px;min-width:0"><div class="bigword" style="font-size:1.8rem">${ko(e.label,true,false)}</div></div></div>
    <div class="narr">${esc(e.desc)}</div>
    ${e.ko?`<div class="koline sign">${ko(e.ko,true,false)}</div><button class="btn" id="evsay" style="justify-content:center">▶ Read aloud</button>`:''}</div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const b=o.querySelector('#evsay');if(b)b.onclick=()=>speak(e.ko,'sign');
}
