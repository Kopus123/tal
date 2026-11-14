/* ============ NOTEBOOK ============
   The word page, the notebook and its tabs, and the little page for names. */

function wordSheet(id){
  const d=W[id];if(!d)return;const r=wrec(id);S.nb[id]=1;save();
  const o=overlay(`<div class="panel paper" role="dialog" aria-label="${esc(id)}">${head('수첩')}<div class="ph-body" id="wsb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const ctx=r.ctx.slice(-4).reverse().map(l=>{const t=plain(l);const k=id.includes('/')?null:id;
    return `<div class="ctx">${k?t.split(k).map(esc).join(`<mark>${esc(k)}</mark>`):esc(t)}</div>`}).join('')||'<div class="empty">Not seen anywhere yet.</div>';
  const draw=()=>{
    const st=status(id);
    const def=d.g?(WORLD.grammar[id]||''):'';
    o.querySelector('#wsb').innerHTML=`<div class="wordhead">${d.g?'':iconSVG(d.p,'bigicon')}<div style="display:flex;flex-direction:column;gap:8px;min-width:0"><div class="bigword">${esc(id)}</div><div><span class="badge st-${st}">${STATE_LABEL[st]}</span></div></div></div>
      ${def?`<div class="defbox">${esc(def)}</div>`:''}
      <button class="btn" id="wsay" style="justify-content:center">▶ Hear it</button>
      ${d.g?'':`<div class="label">What you think it means</div><textarea id="wnote" placeholder="Your own words">${esc(r.note||'')}</textarea>
      <label class="surebox"><input type="checkbox" id="wsure" ${r.sure?'checked':''} ${r.note&&r.note.trim()?'':'disabled'}><span>I'm sure about this</span></label>
      ${r.checked?`<div class="meaning">Meaning: <b>${esc(meaningOf(id))}</b></div>`:meaningOf(id)?`<button class="btn-ink" id="wcheck" ${r.note&&r.note.trim()?'':'disabled'}>Check my guess</button><div class="hintline">${r.note&&r.note.trim()?'Shows the meaning, so you can see if you were right.':'Write a guess first, then you can check it.'}</div>`:''}`}
      <div class="label">Where you've seen it</div>${ctx}
      ${d.g?'':`<button class="linkish" id="wsym">What do the badges on the picture mean?</button>`}`;
    o.querySelector('#wsay').onclick=()=>speak(id,'word');
    const n=o.querySelector('#wnote');if(n)n.oninput=e=>{r.note=e.target.value;if(!r.note.trim())r.sure=0;save();
      const c=o.querySelector('#wsure');c.disabled=!r.note.trim();const wc2=o.querySelector('#wcheck');if(wc2)wc2.disabled=!r.note.trim();if(!r.note.trim())c.checked=false;o.querySelector('.badge').className='badge st-'+status(id);o.querySelector('.badge').textContent=STATE_LABEL[status(id)]};
    const c=o.querySelector('#wsure');if(c)c.onchange=e=>{r.sure=e.target.checked?1:0;save();sfx(r.sure?'learn':'tap');o.querySelector('.badge').className='badge st-'+status(id);o.querySelector('.badge').textContent=STATE_LABEL[status(id)]};
    const wc=o.querySelector('#wcheck');if(wc)wc.onclick=()=>{r.checked=1;save();sfx('learn');draw()};
    const sy=o.querySelector('#wsym');if(sy)sy.onclick=()=>{nbTab='sym';notebook()};
  };
  draw();speak(id,'word');
}

let nbTab='all',nbQ='',nbSort='ko';
const SYMBOLS=()=>`
  <div class="label">Badges on word pictures</div>
  <div class="symrow">${iconSVG('eye +past','symic')}<div><b>Ochre circle with an arrow turning back</b><br>It already happened (past). 봤어요 = saw.</div></div>
  <div class="symrow">${iconSVG('calendar +future','symic')}<div><b>Green square with ››</b><br>It hasn't happened yet (future). 내일 = tomorrow.</div></div>
  <div class="symrow">${iconSVG('exists +not','symic')}<div><b>Red slash</b><br>Not, none, or don't. 없어요 = there isn't any.</div></div>
  <div class="label">Word colors</div>
  <div class="symrow"><span class="w new demo">새</span><div><b>New</b>: the first time you've run into this word.</div></div>
  <div class="symrow"><span class="w seen demo">새</span><div><b>No note yet</b>: you've seen it before but haven't written what it means.</div></div>
  <div class="symrow"><span class="w guess demo">새</span><div><b>Your guess</b>: you wrote a meaning but aren't sure.</div></div>
  <div class="symrow"><span class="w sure demo">새</span><div><b>Sure</b>: you ticked "I'm sure".</div></div>
  <div class="symrow"><span class="w gram demo">는</span><div><b>Grammar piece</b>: a little part that sticks to words. Tap it for an explanation.</div></div>
  <div class="label">In the scene</div>
  <div class="symrow"><span class="glowdemo"></span><div>A golden ring means someone just named that thing.</div></div>
  <div class="symrow"><span class="spotdemo"></span><div>Diamonds are things you can look at or go to.</div></div>
  <div class="symrow"><span class="demo-rw">⏪</span><div>Rewind: that choice didn't work out, so you're back at the decision.</div></div>`;
function notebook(){
  Object.keys(S.w).forEach(id=>S.nb[id]=1);save();
  document.querySelectorAll('#ovs .nbpanel').forEach(x=>x.closest('.ov').remove());
  const o=overlay(`<div class="panel nbpanel">${head('수첩')}<div class="ph-body" id="nbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const draw=()=>{
    const ids=Object.keys(S.w).filter(id=>W[id]);
    const vocab=ids.filter(id=>!W[id].g),gram=ids.filter(id=>W[id].g);
    const by=s=>vocab.filter(id=>status(id)===s);
    let list=nbTab==='all'?vocab:nbTab==='todo'?vocab.filter(id=>['new','seen'].includes(status(id))):nbTab==='guess'?by('guess'):by('sure');
    const eng=id=>((S.w[id].note||'').trim()||(S.w[id].checked?meaningOf(id):'')).toLowerCase();
    if(nbQ){const q=nbQ.toLowerCase();list=list.filter(id=>id.includes(nbQ)||eng(id).includes(q))}
    list=nbSort==='ko'?[...list].sort((a,b)=>a.localeCompare(b,'ko')):nbSort==='en'?[...list].sort((a,b)=>(!eng(a))-(!eng(b))||eng(a).localeCompare(eng(b))||a.localeCompare(b,'ko')):[...list].reverse();
    const pat=ST.patterns[0];
    const tabs=[['all','All'],['todo','No note'],['guess','Guesses'],['sure','Sure'],['gram','Grammar'],['pat','Patterns'],['num','Numbers'],['mix','Mix-ups'],['sym','Symbols']];
    let inner=`<div class="tabs">${tabs.map(([k,t])=>`<button class="tab ${nbTab===k?'on':''}" data-tab="${k}">${t}</button>`).join('')}</div>`;
    if(['all','todo','guess','sure'].includes(nbTab))inner+=`<div class="label">${by('sure').length} sure · ${by('guess').length} guesses · ${vocab.length} seen</div>
      <div class="nbtools"><input id="nbq" placeholder="Search Korean or your notes" value="${esc(nbQ)}" autocomplete="off"><span class="seg">${[['ko','ㄱㄴㄷ'],['en','A–Z'],['new','Newest']].map(([k,t])=>`<button data-sort="${k}" class="${nbSort===k?'on':''}">${t}</button>`).join('')}</span></div>`;
    if(nbTab==='gram'){
      inner+=`<div class="label">Little pieces that stick to words</div>`+(gram.length?`<div class="glist">${gram.map(id=>`<button class="grow" data-w="${esc(id)}"><b>${esc(id)}</b><span>${esc(WORLD.grammar[id]||'')}</span></button>`).join('')}</div>`:`<div class="empty">The ones you run into will collect here.</div>`);
      const tl=Object.keys(WORLD.tells),caught=tl.filter(k=>S.tl[k]);
      inner+=`<div class="label">Tells · ${caught.length} of ${tl.length} caught</div><div class="glist">${caught.map(k=>`<button class="grow tell" data-w="${esc(k)}"><b>${esc(k)}</b><span>${esc(WORLD.tells[k])}</span></button>`).join('')}${tl.length>caught.length?`<div class="grow"><b>?</b><span>How people say things can give them away. Catch it on the case board to add it here.</span></div>`:''}</div>`;
      inner+=`<div class="label">Endings</div><div class="glist">${WORLD.endings.map(e=>`<div class="grow"><b>${esc(e.k)}</b><span>${esc(e.d)}</span></div>`).join('')}</div>`;
    }
    else if(nbTab==='mix'){
      const pairs=Object.entries(S.mx||{});
      inner+=pairs.length?`<div class="empty">Words you heard wrong, next to what was really said. Tap each to hear the difference.</div><div class="glist">${pairs.map(([k,n])=>{const [r,h]=k.split('/');
        const side=(id,lab)=>`<button class="mixw" data-w="${esc(id)}">${W[id]&&W[id].p?iconSVG(W[id].p):''}<b>${esc(id)}</b><small>${lab}</small></button>`;
        return `<div class="mixrow">${side(r,'what they said')}<span class="mixvs">≠</span>${side(h,'what you heard')}${n>1?`<span class="mixn">×${n}</span>`:''}</div>`}).join('')}</div>`
        :`<div class="empty">Nothing yet. When you mishear a word, it goes here next to what was really said.</div>`;
    }
    else if(nbTab==='num'){
      const cell=(k,n)=>`<button class="numcell ${S.w[k]?'met':''}" data-w="${esc(k)}"><b>${esc(k)}</b><span>${n}</span></button>`;
      inner+=`<div class="numintro">Korean has two sets of numbers. <b>Native</b> numbers (green circles) count hours and things: 아홉 시 = 9 o'clock, 두 개 = two of them. <b>Sino-Korean</b> numbers (ochre squares) are for money, minutes and phone numbers: 천 원 = 1,000 won, 삼십 분 = 30 minutes. So 9:30 is 아홉 시 삼십 분.</div>
        <div class="label">Native · hours, counting</div><div class="numgrid">${[['하나 / 한',1],['둘 / 두',2],['셋 / 세',3],['넷 / 네',4],['다섯',5],['여섯',6],['일곱',7],['여덟',8],['아홉',9],['열',10],['열한',11],['열두',12]].map(([k,n])=>cell(k.split(' / ')[0],n).replace(`<b>${esc(k.split(' / ')[0])}</b>`,`<b>${esc(k)}</b>`)).join('')}</div>
        <div class="label">Sino-Korean · money, minutes, phones</div><div class="numgrid">${[['공',0],['일',1],['이',2],['삼',3],['사',4],['오',5],['육',6],['칠',7],['팔',8],['구',9],['십',10],['백',100],['천','1,000'],['만','10,000']].map(([k,n])=>cell(k,n)).join('')}</div>
        <div class="empty">Brighter ones are numbers you've heard in the story. Tap any to hear it.</div>`;
    }
    else if(nbTab==='pat'){
      if(!pat||!F.pattern)inner+=`<div class="empty">Nothing yet. Keep listening to how people talk about what already happened.</div>`;
      else inner+=`<div class="q"><div class="qt">${esc(pat.title)}</div><div class="why">${esc(pat.note)}</div>
        ${pat.pairs.filter(p=>S.w[p[1]]).map(p=>`<div style="font-family:var(--f-ko);font-size:1.3rem">${esc(p[0])} <span style="color:var(--mist)">→</span> <button class="w ${status(p[1])}" data-w="${esc(p[1])}">${esc(p[1])}</button></div>`).join('')}</div>`;
    }
    else if(nbTab==='sym')inner+=`<div class="symlist">${SYMBOLS()}</div>`;
    else inner+=list.length?`<div class="grid">${list.map(id=>{const st=status(id),r=S.w[id];return`<button class="card st-${st}" data-w="${esc(id)}"><span class="k">${esc(id)}</span><span class="note">${esc(r.note||'')}</span><span class="tag">${STATE_LABEL[st]}</span></button>`}).join('')}</div>`:`<div class="empty">Nothing here yet.</div>`;
    o.querySelector('#nbb').innerHTML=inner;
    o.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{nbTab=b.dataset.tab;draw()});
    o.querySelectorAll('[data-sort]').forEach(b=>b.onclick=()=>{nbSort=b.dataset.sort;draw()});
    const nq=o.querySelector('#nbq');if(nq){nq.oninput=()=>{nbQ=nq.value.trim();draw();const n2=o.querySelector('#nbq');n2.focus();n2.setSelectionRange(n2.value.length,n2.value.length)};nq.onclick=e=>e.stopPropagation()}
  };
  draw();NB_REDRAW=draw;
}

function nameSheet(n){const d=(WORLD.names||{})[n];if(!d)return;
  const o=overlay(`<div class="panel paper">${head(d.kind==='sound'?'소리':'이름')}<div class="ph-body"><div class="bigword">${esc(n)}</div>
    <div><span class="badge st-gram">${d.kind==='sound'?'A sound people make':'A name'}</span></div><div class="defbox">${esc(d.d||'')}</div>
    <button class="btn" id="nsay" style="justify-content:center">▶ Hear it</button></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);o.querySelector('#nsay').onclick=()=>speak(n,'word');speak(n,'word')}
