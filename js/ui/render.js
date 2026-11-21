/* ============ THE MAIN SCREEN ============
   Draws the scene window and the paper sheet under it for whatever beat you are on. */

/* ---------- scene layers: art, ambience, hints ---------- */
function glowHTML(ids){
  if(!S.set.glow)return'';const l=ST.places[S.loc];if(!l)return'';
  return l.glow.filter(g=>ids.includes(g.w)&&knowLevel(g.w)<2).map(g=>`<div class="glow ${knowLevel(g.w)?'faint':''}" style="left:${g.x}%;top:${g.y}%;width:${g.r*2}%${g.h?`;height:${g.h*2}%;aspect-ratio:auto`:''}"></div>`).join('');
}
function flashGlow(id){const h=glowHTML([id]);if(!h)return;const fx=$('#fx');fx.querySelectorAll('.glow').forEach(e=>e.remove());fx.insertAdjacentHTML('beforeend',h)}
const AMB_N={leaves:12,petals:12,motes:16,dust:14,snow:26,rain:44};
function ambientHTML(type){
  const n=AMB_N[type]||0;let h='';const r=Math.random;
  for(let i=0;i<n;i++)h+=`<i class="p ${type}" style="left:${(r()*100).toFixed(1)}%;${type==='dust'?`top:${(10+r()*75).toFixed(0)}%;`:''}--d:${(type==='rain'?.5+r()*.4:7+r()*9).toFixed(2)}s;--delay:-${(r()*14).toFixed(2)}s;--s:${(.6+r()*.8).toFixed(2)};--dx:${(r()*70-35).toFixed(0)}px"></i>`;
  return h;
}
const canTravel=()=>{const l=ST.places[S.loc];return !S.node&&!!l&&l.travel!=='no'};
const hasPhone=()=>!!S.F.hasPhone&&ST.phones.length>0;

/* ---------- render ---------- */
function render(){
  const l=ST.places[S.loc]||Object.values(ST.places)[0];const nd=S.node?ST.nodes[S.node]:null;
  document.documentElement.dataset.size=S.set.size;
  panMode(l.mode==='explore');
  $('#locKo').textContent=l.name||'';$('#locSub').textContent=l.sub||'';
  if(S.loc)S.known[S.loc]=1;
  $('#bPhone').hidden=!hasPhone();
  $('#bMap').hidden=!(canTravel()&&ST.map.filter(p=>S.known[p.p]&&ST.places[p.p]).length>1);
  const exam=nd&&nd.type==='examine'?ST.examines[nd.exam]:null;   // a close-up takes over the picture window
  const artName=exam?exam.art:l.art;
  const live=!!ST.free&&!exam,ak=artName+(artName==='bus'?'|'+(S.F.led||''):'')+(live?'|live':'');
  if(ak!==artKey){const w=$('#art');PERSON_OFF=live;try{w.innerHTML=(ART[artName]||ART.madang)()}finally{PERSON_OFF=false}w.classList.remove('in');void w.offsetWidth;w.classList.add('in');artKey=ak}
  const amb=exam?'none':l.ambient||'none';if(amb!==ambKey){$('#amb').innerHTML=ambientHTML(amb);ambKey=amb}
  setScene(l.music||'none',l.sound||'none');
  $('#tint').className='tint t-'+slotName()+(exam?' own':l.light?' '+l.light:'');
  const ck=$('#clock');ck.hidden=!S.F.started||l.mode==='explore';ck.textContent=`${S.world.day}일째 · ${SLOT_KO[slotName()]}`;ck.onclick=dayPanel;
  const wl=$('#wallet');wl.hidden=!S.F.started||l.mode==='explore';wl.textContent=wonStr(S.world.money);wl.onclick=dayPanel;
  let h='';
  if(nd&&nd.type==='camera')h+=`<div class="vf" id="vf" style="left:${cam.x}%;top:${cam.y}%"><span>Drag me</span></div>`;
  if(exam){const got=d=>S.F['ex_'+exam.id+'_'+d.id];
    h+=`<div class="exlayer" id="exam">${exam.compare&&ART[exam.compare]?`<div class="excompare">${ART[exam.compare]()}<span>1979 photo</span></div>`:''}${exam.details.map(d=>got(d)?`<span class="exmark" style="left:${d.x}%;top:${d.y}%"></span>`:EXMISS>=4?`<span class="exhint" style="left:${d.x}%;top:${d.y}%"></span>`:'').join('')}</div>`}
  if(nd&&nd.type==='card')h+=`<div class="card-title"><b>${esc(nd.title)}</b>${nd.sub?`<span>${esc(nd.sub)}</span>`:''}</div>`;
  const xp=!nd&&l.mode==='explore';
  if(xp){const seen=new Set();l.spots.forEach((x,i)=>{if(seen.has(x.l)||!cond(x.c))return;seen.add(x.l);   // the first spot with this label whose COND holds
    h+=`<button class="hs hid ${S.F['f_'+S.loc+'_'+x.l]?'seen':''}" data-hs="${i}" style="left:${x.x}%;top:${x.y}%" aria-label="${esc(x.l)}"></button>`});}
  if(!nd&&!xp)l.spots.forEach((x,i)=>{if(!cond(x.c))return;h+=`<button class="hs ${x.x<25?'edge-l':x.x>75?'edge-r':''}" data-hs="${i}" style="left:${x.x}%;top:${x.y}%" aria-label="${esc(x.l)}"><i></i><span>${esc(x.l)}</span></button>`});
  if(live)peopleHere().forEach(p=>{const a=whereNow(p),n=(ST.cast[p.id]||{}).n||p.id,sty=`left:${a.x}%;top:${a.y}%;--fs:${parseLook((ST.cast[p.id]||{}).look).size||1}`;
    h+=nd?`<div class="hs fig still" style="${sty}" aria-hidden="true">${figureSVG(p.id)}</div>`   // mid-conversation: still there, just not tappable
      :`<button class="hs who fig" data-who="${p.id}" style="${sty}" aria-label="Talk to ${esc(n)}">${figureSVG(p.id)}<span>${esc(n)}</span></button>`});
  if(nd&&nd.ko&&!nd.audio&&glowFor!==S.node){glowFor=S.node;h+=glowHTML(idsIn(nd.ko))}
  if(TIMECARD){TIMECARD=false;if(!(nd&&nd.type==='card')){lastLoc=S.loc;h+=`<div class="placecard"><b>${SLOT_KO[slotName()]}</b><span>day ${S.world.day} · ${slotName()}</span></div>`}}
  if(S.loc!==lastLoc&&l.mode==='explore')panCenter();
  if(S.loc!==lastLoc&&!(nd&&nd.type==='card')&&l.mode!=='explore')h+=`<div class="placecard"><b>${esc(l.name||'')}</b><span>${esc(l.sub||'')}</span></div>`;
  lastLoc=S.loc;
  h+=`<div class="flash" id="flash"></div>`;
  darkLayer(l);
  $('#fx').innerHTML=h;
  $('#fx').querySelectorAll('.hs[data-hs]').forEach(b=>b.onclick=e=>{e.stopPropagation();if(xp)S.F['f_'+S.loc+'_'+l.spots[+b.dataset.hs].l]=1;spot(+b.dataset.hs)});
  $('#fx').onclick=xp?e=>{if(e.target===$('#fx'))emptyTap(e,l)}:null;
  // the back arrow sits on the window, not on the picture (which scrolls)
  let bb=$('#bBackPl');if(xp&&l.back){if(!bb){bb=document.createElement('button');bb.className='backbtn';bb.id='bBackPl';bb.setAttribute('aria-label','Back');bb.textContent='‹';$('#scene').appendChild(bb)}
    bb.onclick=e=>{e.stopPropagation();sfx('tap');enter(l.back)}}else if(bb)bb.remove();
  if(nd&&nd.type==='camera')dragFrame($('#vf'));
  const sb=$('#sb'),sf=$('#sf');let body='',foot='';
  const devSkip=S.set.dev&&nd&&!nd.ch&&!['build','type','present','contradict','number','examine'].includes(nd.type)?`<button class="btn dev" id="bSkip">⏭ Skip to next decision</button>`:'';
  const backBtn=nd&&BACK.length?`<button class="btn back" id="bBack" aria-label="Back one line">‹ Back</button>`:'';
  const cont=label=>`<div class="controw">${backBtn}<button class="btn primary" id="bNext">${label}</button></div>`;
  if(!nd){
    const d=l.desc.find(x=>cond(x.c));
    const chips=l.spots.map((x,i)=>cond(x.c)?`<button class="chipbtn" data-hs="${i}">${esc(x.l)}</button>`:'').join('');
    // free time: wait for a later time of day, and at home in the evening, go to bed
    const run=!S.world.frozen,home=S.loc===ST.meta.home;
    const timeBtn=!run?'':(home&&S.world.slot>=2?`<button class="chipbtn timechip" id="bBed">Go to bed</button>`:'')+(S.world.slot<3?`<button class="chipbtn timechip" id="bWait">Wait a while</button>`:'');
    const who=peopleHere().map(p=>`<button class="chipbtn whochip" data-who="${p.id}">Talk to ${esc((ST.cast[p.id]||{}).n||p.id)}</button>`).join('');
    body=xp?`<div class="narr">${esc(d?d.t:'')}</div>${pocketsHTML()}`:`<div class="narr">${esc(d?d.t:'')}</div><div class="chips">${who}${chips}${timeBtn}</div>`;
  }else if(nd.type==='build'){
    const tl=nd.tiles;
    body=`<div class="en">${esc(nd.en)}</div><div class="built ${nd.join?'joined':''}">${bseq.length?bseq.map(i=>`<span>${ko(tl[i],false,false)}</span>`).join(''):`<span class="ph">${nd.join?'Tap the pieces to build the word':'Tap words to build a sentence'}</span>`}</div>
      <div class="tiles">${tl.map((t,i)=>`<button class="tile" data-t="${i}" ${bseq.includes(i)?'disabled':''}>${ko(t,false,false)}</button>`).join('')}</div>`;
    foot=`<div class="row"><button class="btn" id="bClr" style="justify-content:center">Clear</button><button class="btn primary" id="bSay" ${bseq.length?'':'disabled'}>Say it</button></div><div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
  }else if(nd.type==='type'){
    if(TFB){body=`<div class="en">${esc(nd.en)}</div>${TFB.html}`;foot=cont('Continue')}
    else{
      body=`<div class="en">${esc(nd.en)}</div>${TREPLY?`<div class="treply"><b>${ko(TREPLY.ko,false,false)}</b><span>${esc(TREPLY.en)}</span></div>`:''}<form class="typeans big" id="tf"><input id="tin" lang="ko" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="send" placeholder="Type it in Korean"></form>
        ${tHint?`<div class="hintline">${esc(skeleton(nd,tHint))}</div>`:''}`;
      foot=`<div class="row"><button class="btn" id="bHintT" style="justify-content:center">Hint</button><button class="btn primary" id="bSayT">Say it</button></div><div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
    }
  }else if(nd.type==='present'){
    const ev=owned();
    body=`<div class="en">${esc(nd.en)}</div>${ev.length?`<div class="evlist">${ev.map(e=>`<button class="evcard" data-show="${e.id}">${iconSVG(e.icon)}<span><b>${ko(e.label,false,false)}</b><small>${esc(e.desc)}</small></span></button>`).join('')}</div>`:'<div class="empty">You have nothing to show.</div>'}`;
    foot=`<div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
  }else if(nd.type==='examine'){
    const x=ST.examines[nd.exam],got=d=>S.F['ex_'+x.id+'_'+d.id],keysLeft=x.details.filter(d=>d.key&&!got(d)).length;
    body=`<div class="en">${esc(x.prompt||'Look closely. Tap anything that catches your eye.')} <b>Tap the picture above.</b></div>
      <div class="excount">Noticed ${x.details.filter(got).length} of ${x.details.length}</div>
      ${x.details.filter(got).reverse().map(d=>`<div class="exnote">${ko(d.t,true,true)}</div>`).join('')}`;
    foot=`<div class="controw">${backBtn}<button class="btn primary" id="bNext" ${keysLeft?'disabled':''}>${keysLeft?'Keep looking':'Done looking'}</button></div>`;
  }else if(nd.type==='number'){
    const keys=['1','2','3','4','5','6','7','8','9','⌫','0','✓'];
    body=`<div class="en">${esc(nd.en)}</div><div class="numdisp ${NUMV?'':'ph'}">${NUMV?esc(fmtNum(NUMV,nd.kind)):({time:'_ : _ _',won:'0 원',phone:'010-____-____'}[nd.kind]||'_')}</div>
      <div class="numpad">${keys.map(k=>`<button class="nk ${k==='✓'?'ok':''}" data-nk="${k}" ${k==='✓'&&!NUMV?'disabled':''}>${k==='✓'?(nd.kind==='won'?'Pay':'Say it'):k}</button>`).join('')}</div>`;
    foot=`<div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
  }else if(nd.type==='contradict'){
    const sts=ownedSt(),ev=owned(),sel=k=>CSEL.includes(k)?'sel':'';
    body=`<div class="en">${esc(nd.en)}</div>
      ${sts.length?`<div class="label">Statements</div><div class="evlist">${sts.map(x=>stCard(x,`data-cx="${x.id}" class="evcard stcard ${sel(x.id)}"`)).join('')}</div>`:''}
      ${ev.length?`<div class="label">Evidence</div><div class="evlist">${ev.map(e=>`<button class="evcard ${sel(e.id)}" data-cx="${e.id}">${iconSVG(e.icon)}<span><b>${ko(e.label,false,false)}</b><small>${esc(e.desc)}</small></span></button>`).join('')}</div>`:''}`;
    foot=`<button class="btn primary" id="bClash" style="justify-content:center" ${CSEL.length===2?'':'disabled'}>${CSEL.length===2?'These two can\'t both be true':`Pick two (${CSEL.length}/2)`}</button><div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
  }else if(nd.type==='camera'){
    body=`<div class="narr">${esc(nd.en)}</div>`;foot=`<button class="shutter" id="bShut" aria-label="Take photo"></button>`;
  }else if(nd.type==='photo'){
    body=`<svg class="photo" viewBox="0 0 300 220">${photoArt()}</svg><div class="narr">${esc(nd.en)}</div>`;
    foot=`${cont('Continue')}${devSkip}`;
  }else if(nd.type==='card'){
    body=`<div class="en" style="margin:auto;text-align:center">Sound on. Tap any underlined word to see a picture of it and write down what you think it means.</div>`;foot=`${cont('Begin')}${devSkip}`;
  }else{
    const c=ST.cast[nd.who]||{};
    if(nd.who==='narr')body=nd.en?`<div class="narr">${esc(nd.en)}</div>`:'';
    else if(nd.who==='sign')body=`<div class="koline sign">${ko(nd.ko)}</div><div class="who"><button class="say" data-say>▶ Read aloud</button></div>${nd.en?`<div class="en">${esc(nd.en)}</div>`:''}`;
    else{
      const face=c.look?portrait(c.look,nd.ex):speakerGlyph();
      const anim=revealFor!==S.node?nd.ex:'';
      body=`<div class="line"><div class="spk"><div class="pt ${anim}" style="--cbg:${c.c||'#888'}">${face}</div><div class="seal">${esc(c.n||'')}</div></div>
        <div class="talk">${nd.audio?heardHTML(nd):`<div class="koline ${nd.who==='bus'?'led':''}">${ko(nd.ko)}</div><button class="say" data-say aria-label="Hear it again">▶ Again</button>`}</div></div>
        ${enHTML(nd)}`;
    }
    if(nd.ch)foot=`<div class="acts">${nd.ch.map((x,i)=>!cond(x.c)?'':`<button class="btn ${x.ko?'ko':'act'}" data-ch="${i}">${x.ko?`<span class="qm">“</span><span>${ko(x.ko,false,false)}<span class="qm">”</span></span>`:esc(x.en)}</button>`).join('')}</div>${backBtn?`<div class="controw">${backBtn}</div>`:''}`;
    else foot=`${cont(nd.next||nd.rewind?'Continue':'Look around')}${devSkip}`;
  }
  const keepTop=S.node&&S.node===RNODE?sb.scrollTop:0;RNODE=S.node;
  sb.innerHTML=body;sf.innerHTML=foot;sb.scrollTop=keepTop;setBusy(busy);
  if(nd&&revealFor!==S.node){revealFor=S.node;const k=sb.querySelector('.koline,.narr');const ms=reveal(k);revealUntil=Date.now()+ms;
    const en=sb.querySelector('.en');if(en){en.classList.add('rv');en.style.animationDelay=Math.min(ms,1400)+'ms'}}
  document.querySelectorAll('#sb [data-hs],#sf [data-hs]').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  document.querySelectorAll('#fx [data-who],#sb [data-who]').forEach(b=>b.onclick=()=>talkTo(b.dataset.who));
  sf.querySelectorAll('[data-ch]').forEach(b=>b.onclick=()=>choose(nd.ch[+b.dataset.ch]));
  const bn=$('#bNext');if(bn)bn.onclick=TFB?()=>{const t=TFB.target;TFB=null;go(t)}:next;
  if($('#bSayT')){const tin=$('#tin');$('#bSayT').onclick=()=>sayTyped(nd,tin.value);$('#tf').onsubmit=e=>{e.preventDefault();sayTyped(nd,tin.value)};
    $('#bHintT').onclick=()=>{tHint=Math.min(tHint+1,3);const v=tin.value;render();const t2=$('#tin');t2.value=v;t2.focus()}}
  if($('#bSkip'))$('#bSkip').onclick=skipAhead;
  sb.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>pocket(b.dataset.pk));
  if($('#bWait'))$('#bWait').onclick=()=>{sfx('page');passTime();if(!S.node)render()};
  if($('#bBed'))$('#bBed').onclick=()=>{sfx('page');nextMorning();render()};
  sb.querySelectorAll('[data-show]').forEach(b=>b.onclick=()=>present(nd,b.dataset.show));
  sb.querySelectorAll('[data-cx]').forEach(b=>b.onclick=()=>{const k=b.dataset.cx;sfx('tap');
    if(CSEL.includes(k))CSEL=CSEL.filter(x=>x!==k);else{CSEL.push(k);if(CSEL.length>2)CSEL.shift()}
    const top=sb.scrollTop;render();sb.scrollTop=top});
  if($('#bClash'))$('#bClash').onclick=()=>clash(nd);
  const ex=$('#exam');if(ex)ex.onclick=e=>{const r=ex.getBoundingClientRect();examTap(nd,(e.clientX-r.left)/r.width*100,(e.clientY-r.top)/r.height*100)};
  sb.querySelectorAll('[data-nk]').forEach(b=>b.onclick=()=>{const k=b.dataset.nk;sfx('tap');
    if(k==='✓'){sayNumber(nd);return}if(k==='⌫')NUMV=NUMV.slice(0,-1);else if(NUMV.length<11)NUMV+=k;render()});
  if($('#bBack'))$('#bBack').onclick=goBack;
  const es=sb.querySelector('#enShow');if(es)es.onclick=()=>{ENOPEN=S.node;const top=sb.scrollTop;render();sb.scrollTop=top};
  const bs=sb.querySelector('[data-say]');if(bs)bs.onclick=()=>{sfx('tap');speak(nd.ko,nd.who)};
  sb.querySelectorAll('[data-t]').forEach(b=>b.onclick=()=>{sfx('tap');bseq.push(+b.dataset.t);if(!nd.join)speak(nd.tiles[+b.dataset.t],'you');render()});
  if($('#bClr'))$('#bClr').onclick=()=>{bseq=[];render()};
  if($('#bLeave'))$('#bLeave').onclick=()=>{S.node=null;BACK=[];save();render()};
  if($('#bSay'))$('#bSay').onclick=()=>say(nd);
  if($('#bShut'))$('#bShut').onclick=()=>shoot(nd);
  dots();save();
}
/* ---------- explore mode: darkness, the flashlight, pockets ---------- */
// night: a dark layer over the picture. With the flashlight on, a circle of light follows your finger.
function darkLayer(l){let d=$('#dark');const lvl=l&&l.dark?+l.dark:0;
  if(!d){d=document.createElement('div');d.id='dark';d.className='dark'}if(d.nextSibling!==$('#fx'))$('#fx').parentNode.insertBefore(d,$('#fx'))
  d.hidden=!lvl;d.style.setProperty('--dk',lvl);d.classList.toggle('lit',!!S.F.lit)}
let LIGHT={x:50,y:45};
['pointerdown','pointermove'].forEach(t=>document.addEventListener(t,e=>{if(!S.F||!S.F.lit)return;const sc=$('#dark');if(!sc||(t==='pointermove'&&!e.buttons&&e.pointerType!=='mouse'))return;
  const r=sc.getBoundingClientRect(),v=$('#scene').getBoundingClientRect();if(e.clientX<v.left||e.clientX>v.right||e.clientY<v.top||e.clientY>v.bottom)return;if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)return;
  LIGHT={x:(e.clientX-r.left)/r.width*100,y:(e.clientY-r.top)/r.height*100};const d=$('#dark');if(d){d.style.setProperty('--lx',LIGHT.x+'%');d.style.setProperty('--ly',LIGHT.y+'%')}},{passive:true}));
// tapping where there's nothing: a ripple, and in the dark, a reminder that you can't see
function emptyTap(e,l){const fx=$('#fx'),r=fx.getBoundingClientRect(),px=(e.clientX-r.left)/r.width*100,py=(e.clientY-r.top)/r.height*100;
  const p=document.createElement('span');p.className='exripple';p.style.left=px+'%';p.style.top=py+'%';fx.appendChild(p);setTimeout(()=>p.remove(),600);sfx('tap');
  if(l.dark&&!S.F.lit&&+l.dark>.6){EMPTY++;if(EMPTY%3===1)toast('Too dark to make anything out.',2200)}}
let EMPTY=0;
// the room as a wide picture inside a tall window: the art, the darkness and the tap layer move together when you swipe
let PANNED=false;
function panMode(on){const app=$('#app');if(!!on===app.classList.contains('explore'))return;app.classList.toggle('explore',!!on);
  const sc=$('#scene');let pan=$('#pan');
  if(on){if(!pan){pan=document.createElement('div');pan.id='pan';pan.className='pan';pan.innerHTML='<div class="panin" id="panin"></div>';sc.insertBefore(pan,sc.firstChild)}
    const pin=$('#panin');['#art','#tint','#amb','#dark','#fx'].forEach(q=>{const e=$(q);if(e)pin.appendChild(e)});pan.hidden=false;PANNED=false}
  else if(pan){['#art','#tint','#amb','#dark','#fx'].forEach(q=>{const e=$(q);if(e)sc.insertBefore(e,pan)});pan.hidden=true}}
// a new view starts looking at the middle of the room
function panCenter(){const pan=$('#pan');if(!pan||pan.hidden)return;requestAnimationFrame(()=>{pan.scrollLeft=(pan.scrollWidth-pan.clientWidth)/2})}
// what you're carrying: tap the flashlight to switch it on and off; tap anything else to hold it, then tap where to use it
function pocketsHTML(){const items=owned().filter(e=>e.icon!=='letter');if(!items.length)return'';
  return `<div class="label">Pockets</div><div class="pockets">${items.map(e=>{const on=e.id==='flashlight'?S.F.lit:S.F.hold===e.id;
    return `<button class="pkt ${on?'on':''}" data-pk="${e.id}" aria-pressed="${!!on}">${iconSVG(e.icon)}<span>${ko(e.label,false,false)}</span></button>`}).join('')}</div>
    <div class="pkhint">${S.F.hold&&ST.evidence[S.F.hold]?`Holding: ${ko(ST.evidence[S.F.hold].label,false,false)}. Tap where to use it.`:S.F.lit?'Flashlight on. Touch the picture to point it.':'Swipe the picture to look around. Tap something in your pockets to take it out.'}</div>`}
function pocket(id){sfx('click');
  if(id==='flashlight')S.F.lit=S.F.lit?0:1;else S.F.hold=S.F.hold===id?null:id;
  const top=$('#sb').scrollTop;render();$('#sb').scrollTop=top}
// a line you only hear: a listen button, and pictures for the words you've already looked up (no text)
function heardHTML(nd){
  const pics=(HEARD[nd.id]||0)<2?'':idsIn(nd.ko).filter((id,i,a)=>a.indexOf(id)===i&&W[id]&&!W[id].g&&S.nb[id]).map(id=>iconSVG(W[id].p,'hicon')).join('');
  return `<div class="heardbox"><button class="listen" data-say aria-label="Listen again">🔊 Listen again</button>${pics?`<div class="heardpics">${pics}</div>`:''}<div class="heardnote">${pics?'Pictures for the words you know.':'You only heard this. It gets written down once you act on it.'}</div></div>`}
let RNODE=null,ENOPEN=null;
// what you see them do. Once you know every word in the line, it folds away behind a small button: the Korean is enough.
function enHTML(nd){if(!nd.en)return'';
  if(nd.audio||ENOPEN===nd.id||!lineKnown(nd.ko))return `<div class="en">${esc(nd.en)}</div>`;
  return `<button class="enshow" id="enShow">show what they do</button>`}
function reveal(el){
  if(!el)return 0;let i=0;const step=55;
  [...el.childNodes].forEach(n=>{
    if(n.nodeType===3){const frag=document.createDocumentFragment();
      n.textContent.split(/(\s+)/).forEach(p=>{if(!p)return;if(/^\s+$/.test(p)){frag.appendChild(document.createTextNode(p));return}
        const s=document.createElement('span');s.className='rv';s.style.animationDelay=(i++*step)+'ms';s.textContent=p;frag.appendChild(s)});
      n.replaceWith(frag)}
    else if(n.nodeType===1&&n.tagName!=='BR'){n.classList.add('rv');n.style.animationDelay=(i++*step)+'ms'}
  });
  return i*step;
}
function dots(){
  $('#noteDot').hidden=!Object.keys(S.w).some(id=>W[id]&&!W[id].g&&!S.nb[id]);
  $('#caseDot').hidden=!ST.cases.some(q=>cond(q.c)&&!S.cs[q.id]);
  $('#phoneDot').hidden=!ST.phones.some(unread);
}

/* camera: drag the frame over the people, then shoot */
function dragFrame(el){
  if(!el)return;const sc=$('#scene');let start=null;
  el.onpointerdown=e=>{e.preventDefault();el.setPointerCapture(e.pointerId);const r=sc.getBoundingClientRect();start={px:e.clientX,py:e.clientY,x:cam.x,y:cam.y,w:r.width,h:r.height}};
  el.onpointermove=e=>{if(!start)return;
    cam.x=Math.max(0,Math.min(56,start.x+(e.clientX-start.px)/start.w*100));
    cam.y=Math.max(0,Math.min(48,start.y+(e.clientY-start.py)/start.h*100));
    el.style.left=cam.x+'%';el.style.top=cam.y+'%'};
  el.onpointerup=el.onpointercancel=()=>{start=null};
}
function shoot(nd){
  const inX=nd.tx>=cam.x+6&&nd.tx<=cam.x+44-6,inY=nd.ty>=cam.y+6&&nd.ty<=cam.y+52-6;
  if(!(inX&&inY)){sfx('wrong');buzz(40);toast('They\'re not in the frame yet. Drag the frame over them first.');return}
  sfx('tap');const f=$('#flash');f.classList.remove('go');void f.offsetWidth;f.classList.add('go');setTimeout(()=>go(nd.next),500);
}

/* the paper only finishes the word-by-word reveal; moving on is always the Continue button */
document.addEventListener('click',e=>{
  const sb=e.target.closest('#sb');if(!sb||e.target.closest('button,textarea,a,input'))return;
  if(Date.now()<revealUntil){sb.querySelectorAll('.rv').forEach(x=>x.style.animationDelay='0ms');revealUntil=0}
});
document.addEventListener('click',e=>{const b=e.target.closest('[data-name]');if(b){e.stopPropagation();sfx('tap');nameSheet(b.dataset.name)}},true);
/* word taps anywhere: open the notebook page for that word */
document.addEventListener('click',e=>{const b=e.target.closest('.w,[data-w]');if(b&&b.dataset.w){e.stopPropagation();sfx('tap');
  if(b.closest('#sb'))flashGlow(b.dataset.w);wordSheet(b.dataset.w)}},true);
