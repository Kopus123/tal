/* ============ ENGINE ============
   Reads story/*.story and runs it. Nothing about the plot lives in this file. */

const STORY_FILES=['story/prologue.story'];
let ST=null;          // parsed story
let W={};             // words -> {p: picture spec, g: grammar}

/* ---------- story parser ---------- */
function parseStory(src,st){
  st=st||{cast:{},words:{},places:{},nodes:{},cases:[],phones:[],hints:[],patterns:[],meta:{}};
  let sec=null,cur=null,scene=null,last=null,count=0;
  const node=n=>{count++;const id=count===1?scene:scene+'.'+count;
    if(last&&!last.next&&!last.ch&&!last.ans)last.next=id;
    n.id=id;st.nodes[id]=n;last=n;return n};
  const fx=s=>s.split(';').map(x=>x.trim()).filter(Boolean).map(x=>{
    const m=x.match(/^(\w+)\s+(.+?)(?:\s+if\s+(\S+))?$/);return m?{k:m[1],a:m[2].trim(),c:m[3]}:null}).filter(Boolean);
  const nl=s=>s.replace(/\\n/g,'\n');
  src.split(/\r?\n/).forEach((raw,ln)=>{
    const line=raw.trim();if(!line||line.startsWith('#'))return;
    const h=line.match(/^===\s*(\w+)\s*(.*)$/);
    if(h){sec=h[1];const arg=h[2].trim();
      if(sec==='scene'){scene=arg;last=null;count=0}
      else if(sec==='place')cur=st.places[arg]={id:arg,spots:[],glow:[],desc:[]};
      else if(sec==='phone'){cur={id:arg,m:[],fx:[]};st.phones.push(cur)}
      else if(sec==='pattern'){cur={id:arg,pairs:[],need:3};st.patterns.push(cur)}
      return}
    let m;
    switch(sec){
      case 'meta':{const i=line.indexOf(' ');st.meta[line.slice(0,i)]=line.slice(i+1).trim();break}
      case 'cast':{const [k,n,c,v,look]=line.split('|').map(s=>s.trim());st.cast[k]={n,c,voice:!!v,look:look||''};break}
      case 'words':{m=line.match(/^(.+?)\s*=\s*(.+)$/);if(m)st.words[m[1]]=m[2]==='(grammar)'?{g:1}:{p:m[2]};break}
      case 'hints':{m=line.match(/^if\s+(\S+):\s*(.+)$/);st.hints.push(m?{c:m[1],t:m[2]}:{t:line});break}
      case 'case':{m=line.match(/^(\w+)\s+(\S+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        if(m)st.cases.push({id:m[1],a:m[2],final:!!m[3],c:m[4],q:m[5],why:m[6]});break}
      case 'pattern':{if(m=line.match(/^title\s+(.+)/))cur.title=m[1];else if(m=line.match(/^note\s+(.+)/))cur.note=m[1];
        else if(m=line.match(/^need\s+(\d+)/))cur.need=+m[1];else if(m=line.match(/^(.+?)\s*>\s*(.+)$/))cur.pairs.push([m[1],m[2]]);break}
      case 'place':{
        if(m=line.match(/^(name|sub|art|first|always|ambient)\s+(.+)$/))cur[m[1]]=m[2];
        else if(m=line.match(/^desc\s+(?:if\s+(\S+):\s*)?(.+)$/))cur.desc.push({c:m[1],t:m[2]});
        else if(m=line.match(/^spot\s+"([^"]+)"\s+([\d.]+)\s+([\d.]+)\s+(->|=>)\s+(.+?)(?:\s+if\s+(\S+))?$/))
          cur.spots.push({l:m[1],x:+m[2],y:+m[3],kind:m[4],t:m[5],c:m[6]});
        else if(m=line.match(/^glow\s+(.+?)\s+([\d.]+)\s+([\d.]+)(?:\s+([\d.]+))?$/))cur.glow.push({w:m[1],x:+m[2],y:+m[3],r:+(m[4]||8)});
        break}
      case 'phone':{
        if(m=line.match(/^name\s+(.+)/))cur.name=m[1];
        else if(m=line.match(/^avatar\s+(\S+)\s+(\S+)/)){cur.av=m[1];cur.c=m[2]}
        else if(m=line.match(/^on-open\s+(.+)/))cur.fx=fx(m[1]);
        else if(m=line.match(/^day\s+(.+)/))cur.m.push({d:m[1]});
        else if(m=line.match(/^(them|me)\s+(\S+)\s+(.+)/))cur.m.push({me:m[1]==='me',t:m[2],ko:m[3]});
        else if(m=line.match(/^sys\s+(.+)/))cur.m.push({sys:1,ko:m[1]});
        else if(m=line.match(/^note\s+(.+)/))cur.note=m[1];
        break}
      case 'scene':{
        if(line.startsWith('~'))node({who:'narr',en:line.slice(1).trim()});
        else if(m=line.match(/^\((.*)\)$/)){if(last)last.en=m[1]}
        else if(line.startsWith('!')){if(last)last.fx=(last.fx||[]).concat(fx(line.slice(1)))}
        else if(m=line.match(/^\*\s+(.+?)\s+->\s+(.+?)(?:\s+!\s+(.+))?$/)){
          const lab=m[1];(last.ch=last.ch||[]).push(lab.startsWith('[')?{en:lab.replace(/^\[|\]$/g,''),go:m[2],fx:m[3]?fx(m[3]):[]}:{ko:lab,go:m[2],fx:m[3]?fx(m[3]):[]})}
        else if(m=line.match(/^->\s*(.+)$/)){if(last)last.next=m[1].trim()}
        else if(m=line.match(/^@build\s+(.+)$/))node({type:'build',en:m[1],tiles:[],ans:[]});
        else if(m=line.match(/^tiles:\s*(.+)$/))last.tiles=m[1].split('|').map(s=>s.trim());
        else if(m=line.match(/^answer:\s*(.+?)\s+->\s+(.+)$/))last.ans.push([m[1].split('|').map(s=>s.trim()),m[2].trim()]);
        else if(m=line.match(/^miss\s+->\s+(.+)$/))last.miss=m[1].trim();
        else if(m=line.match(/^@camera\s+(.+)$/))node({type:'camera',en:m[1]});
        else if(m=line.match(/^@photo\s+(.+)$/))node({type:'photo',en:m[1]});
        else if(m=line.match(/^@card\s+(.+?)(?:\s*\|\s*(.+))?$/))node({type:'card',title:m[1],sub:m[2]||''});
        else if(m=line.match(/^([a-z_]+)(?:\[(\w+)\])?:\s*(.+)$/))node({who:m[1],ex:m[2]||'neutral',ko:nl(m[3])});
        else console.warn('story line not understood',ln+1,line);
        break}
    }
  });
  return st;
}

/* ---------- state ---------- */
const KEY='tal-save-v2';
const fresh=()=>({loc:null,node:null,F:{},w:{},cs:{},nb:{},log:[],set:{auto:1,slow:0,glow:1,sound:1,size:1},visited:{}});
let S=fresh();
function load(){try{const r=localStorage.getItem(KEY);if(r){S=Object.assign(fresh(),JSON.parse(r));S.set=Object.assign(fresh().set,S.set);return true}}catch(e){}return false}
function save(){try{localStorage.setItem(KEY,JSON.stringify(S))}catch(e){}}
const F=new Proxy({},{get:(t,k)=>S.F[k],set:(t,k,v)=>{S.F[k]=v;return true}});
function cond(c){if(!c)return true;return c.split('&').every(t=>{t=t.trim();
  if(t.startsWith('@'))return S.loc===t.slice(1);if(t.startsWith('!'))return !S.F[t.slice(1)];return !!S.F[t]})}
function tgt(t){const m=String(t).match(/^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$/);return m?(cond(m[1])?m[2]:m[3]):String(t).trim()}

/* ---------- tokens & words ---------- */
const TOK=/\{([^}|]+)(?:\|([^}]+))?\}/g;
const plain=s=>String(s).replace(TOK,'$1');
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const idsIn=s=>[...String(s).matchAll(TOK)].map(m=>m[2]||m[1]);
function wrec(id){return S.w[id]||(S.w[id]={ctx:[],L:0,note:''})}
function see(id,line){if(!W[id])return;const r=wrec(id);if(!r.ctx.includes(line)){r.ctx.push(line);if(r.ctx.length>6)r.ctx.shift();r.n=(r.n||0)+1}}
function status(id){const d=W[id];if(!d)return'new';if(d.g)return'gram';return S.w[id]&&S.w[id].L?'learned':'new'}
function ko(str,tap=true,mark=true){
  return esc(str).replace(TOK,(m,surf,id)=>{id=id||surf;if(mark)see(id,str);
    return tap?`<button class="w ${status(id)}" data-w="${id}">${surf}</button>`:surf}).replace(/\n/g,'<br>');
}
function learn(id,quiet){if(!W[id]||W[id].g)return;const r=wrec(id);if(r.L)return;r.L=1;
  if(!quiet){toast(`${iconSVG(W[id].p)} <b>${esc(id)}</b> figured out`);sfx('learn');buzz(25)}checkPattern()}
function checkPattern(){const p=ST.patterns[0];if(!p||F.pattern)return;
  if(p.pairs.filter(x=>S.w[x[1]]).length>=p.need){F.pattern=1;toast('Pattern spotted. Check your notebook.')}}

/* ---------- voice ---------- */
let VOICE=null,AUD=null;
function pickVoice(){const vs=speechSynthesis.getVoices();VOICE=vs.find(v=>/^ko/i.test(v.lang)&&/google/i.test(v.name))||vs.find(v=>/^ko/i.test(v.lang))||null}
if('speechSynthesis' in window){pickVoice();speechSynthesis.onvoiceschanged=pickVoice}
// must match normalize() in tools/build_audio.py
const normT=s=>plain(s).replace(/[📸🏮^♡✖📞🔔💙]/gu,'').replace(/\//g,', ').replace(/\s+/g,' ').trim();
const vg=who=>ST&&ST.cast[who]&&ST.cast[who].voice?who:'sign';
// Resolves when the line finishes (or after 7s at most), so callers can wait for it.
function speak(text,who){
  return new Promise(done=>{
    const t=normT(text);if(!t)return done();
    const f=window.AUDIO&&window.AUDIO[vg(who)+'|'+t];
    if(AUD){AUD.pause();AUD=null}
    if('speechSynthesis' in window)speechSynthesis.cancel();
    const cap=setTimeout(done,7000),fin=()=>{clearTimeout(cap);done()};
    if(f){const a=AUD=new Audio(f);a.playbackRate=S.set.slow?.75:1;a.preservesPitch=true;a.onended=fin;
      a.play().catch(()=>tts(t,fin));return}
    tts(t,fin);
  });
}
function tts(t,fin){
  if(!('speechSynthesis' in window)){fin&&fin();return}
  const u=new SpeechSynthesisUtterance(t);u.lang='ko-KR';if(VOICE)u.voice=VOICE;
  if(fin){u.onend=fin;u.onerror=fin}u.rate=S.set.slow?.62:.88;speechSynthesis.speak(u);
}

/* ---------- sound effects & vibration (synthesized, no files) ---------- */
let AC=null;
function ac(){if(!AC){try{AC=new(window.AudioContext||window.webkitAudioContext)()}catch(e){return null}}if(AC.state==='suspended')AC.resume();return AC}
function tone(f,t0,dur,type='triangle',vol=.12){const c=ac();if(!c)return;const o=c.createOscillator(),g=c.createGain(),t=c.currentTime+t0;
  o.type=type;o.frequency.value=f;g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(vol,t+.008);g.gain.exponentialRampToValueAtTime(.0001,t+dur);
  o.connect(g).connect(c.destination);o.start(t);o.stop(t+dur+.05)}
function noise(t0,dur,vol,freq){const c=ac();if(!c)return;const len=Math.floor(c.sampleRate*dur),b=c.createBuffer(1,len,c.sampleRate),d=b.getChannelData(0);
  for(let i=0;i<len;i++)d[i]=(Math.random()*2-1)*(1-i/len);const s=c.createBufferSource(),f=c.createBiquadFilter(),g=c.createGain(),t=c.currentTime+t0;
  s.buffer=b;f.type='bandpass';f.frequency.value=freq;f.Q.value=.8;g.gain.value=vol;s.connect(f).connect(g).connect(c.destination);s.start(t)}
const SFX={
  tap:()=>{tone(1400,0,.045,'sine',.05);noise(0,.025,.05,2600)},          // wooden tok
  page:()=>noise(0,.16,.05,1600),                                          // paper turn
  open:()=>noise(0,.1,.04,900),
  learn:()=>{tone(784,0,.55,'triangle',.1);tone(1175,.09,.7,'triangle',.08)},           // two-note chime
  solve:()=>[523,659,784,1047].forEach((f,i)=>tone(f,i*.08,.8,'triangle',.08)),         // rising pluck
  wrong:()=>tone(140,0,.22,'sine',.12)
};
function sfx(n){if(!S.set.sound)return;try{SFX[n]&&SFX[n]()}catch(e){}}
function buzz(p){if(S.set.sound&&navigator.vibrate)try{navigator.vibrate(p)}catch(e){}}

/* ---------- flow ---------- */
const $=s=>document.querySelector(s);
let bseq=[],busy=false,glowFor=null,revealFor=null,revealUntil=0,artKey=null,ambKey=null,lastLoc=null;
function runFx(list){(list||[]).forEach(e=>{if(e.c&&!cond(e.c))return;const a=e.a;
  if(e.k==='set')a.split(',').forEach(f=>S.F[f.trim()]=1);
  else if(e.k==='unset')a.split(',').forEach(f=>delete S.F[f.trim()]);
  else if(e.k==='learn')a.split(',').forEach(w=>learn(w.trim()));
  else if(e.k==='place')S.loc=a;
  else if(e.k==='led')S.F.led=a;
  else if(e.k==='toast')toast(esc(a));
})}
function logLine(e){S.log.push(e);if(S.log.length>80)S.log.shift()}
function enter(place){
  S.loc=place;const l=ST.places[place];S.node=null;
  if(l.always){go(l.always);return}
  if(l.first&&!S.visited[place]){S.visited[place]=1;go(l.first);return}
  S.visited[place]=1;save();render();
}
function go(id){
  id=tgt(id);const nd=ST.nodes[id];if(!nd){console.warn('no scene',id);S.node=null;save();render();return}
  S.node=id;bseq=[];runFx(nd.fx);
  if(nd.ko||(nd.who==='narr'&&nd.en))logLine({who:nd.who,ex:nd.ex,ko:nd.ko,en:nd.en});
  save();render();
  if(S.set.auto&&nd.ko)speak(nd.ko,nd.who);
}
function next(){sfx('page');const nd=ST.nodes[S.node];if(nd&&nd.next)go(nd.next);else{S.node=null;save();render()}}
function setBusy(b){busy=b;const f=$('#sf');if(f)f.style.opacity=b?.55:''}
async function choose(c){
  if(busy)return;sfx('tap');setBusy(true);runFx(c.fx);
  if(c.ko){ko(c.ko);logLine({who:'you',ko:c.ko});await speak(c.ko,'you');await new Promise(r=>setTimeout(r,250))}
  setBusy(false);go(c.go);
}
async function say(nd){
  if(busy)return;sfx('tap');setBusy(true);
  const words=bseq.map(i=>nd.tiles[i]);const line=words.join(' ');ko(line);logLine({who:'you',ko:line});
  const hit=nd.ans.find(a=>a[0].length===words.length&&a[0].every((w,i)=>w===words[i]));
  if(hit)idsIn(line).forEach(x=>learn(x));
  await speak(line,'you');await new Promise(r=>setTimeout(r,250));
  setBusy(false);go(hit?hit[1]:nd.miss);
}
function spot(i){const x=ST.places[S.loc].spots[i];if(!x)return;sfx('tap');
  if(x.kind==='->')go(x.t);else if(x.t==='phone')openPhone();else{const m=x.t.match(/^place\s+(\S+)/);if(m)enter(m[1])}}

/* ---------- scene layers: art, ambience, hints ---------- */
function glowHTML(ids){
  if(!S.set.glow)return'';const l=ST.places[S.loc];if(!l)return'';
  return l.glow.filter(g=>ids.includes(g.w)).map(g=>`<div class="glow" style="left:${g.x}%;top:${g.y}%;width:${g.r*2}%"></div>`).join('');
}
function flashGlow(id){const h=glowHTML([id]);if(!h)return;const fx=$('#fx');fx.querySelectorAll('.glow').forEach(e=>e.remove());fx.insertAdjacentHTML('beforeend',h)}
const AMB_N={leaves:12,petals:12,motes:16,dust:14,snow:26,rain:44};
function ambientHTML(type){
  const n=AMB_N[type]||0;let h='';const r=Math.random;
  for(let i=0;i<n;i++)h+=`<i class="p ${type}" style="left:${(r()*100).toFixed(1)}%;${type==='dust'?`top:${(10+r()*75).toFixed(0)}%;`:''}--d:${(type==='rain'?.5+r()*.4:7+r()*9).toFixed(2)}s;--delay:-${(r()*14).toFixed(2)}s;--s:${(.6+r()*.8).toFixed(2)};--dx:${(r()*70-35).toFixed(0)}px"></i>`;
  return h;
}

/* ---------- render ---------- */
function render(){
  const l=ST.places[S.loc]||Object.values(ST.places)[0];const nd=S.node?ST.nodes[S.node]:null;
  document.documentElement.dataset.size=S.set.size;
  $('#locKo').textContent=l.name||'';$('#locKo').dataset.w=W[l.name]?l.name:'';$('#locSub').textContent=l.sub||'';
  // art (only redrawn when it changes, so ambience and fades stay smooth)
  const ak=l.art+(l.art==='bus'?'|'+(S.F.led||''):'');
  if(ak!==artKey){const w=$('#art');w.innerHTML=(ART[l.art]||ART.madang)();w.classList.remove('in');void w.offsetWidth;w.classList.add('in');artKey=ak}
  const amb=l.ambient||'none';if(amb!==ambKey){$('#amb').innerHTML=ambientHTML(amb);ambKey=amb}
  // foreground: hotspots, glow, place card, viewfinder
  let h='';
  if(nd&&nd.type==='camera')h+=`<div class="vf"></div>`;
  if(nd&&nd.type==='card')h+=`<div class="card-title"><b>${esc(nd.title)}</b>${nd.sub?`<span>${esc(nd.sub)}</span>`:''}</div>`;
  if(!nd)l.spots.forEach((x,i)=>{if(!cond(x.c))return;h+=`<button class="hs" data-hs="${i}" style="left:${x.x}%;top:${x.y}%" aria-label="${esc(x.l)}"><i></i><span>${esc(x.l)}</span></button>`});
  if(nd&&nd.ko&&glowFor!==S.node){glowFor=S.node;h+=glowHTML(idsIn(nd.ko))}
  if(S.loc!==lastLoc&&!(nd&&nd.type==='card')){h+=`<div class="placecard"><b>${esc(l.name||'')}</b><span>${esc(l.sub||'')}</span></div>`}
  lastLoc=S.loc;
  h+=`<div class="flash" id="flash"></div>`;
  $('#fx').innerHTML=h;
  $('#fx').querySelectorAll('.hs').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  // dialogue sheet
  const sb=$('#sb'),sf=$('#sf');let body='',foot='';
  if(!nd){
    const d=l.desc.find(x=>cond(x.c));body=`<div class="narr">${esc(d?d.t:'')}</div>`;
    foot=`<div class="acts">${l.spots.map((x,i)=>cond(x.c)?`<button class="btn act" data-hs="${i}">${esc(x.l)}</button>`:'').join('')}</div>`;
  }else if(nd.type==='build'){
    const tl=nd.tiles;
    body=`<div class="en">${esc(nd.en)}</div><div class="built">${bseq.length?bseq.map(i=>`<span>${ko(tl[i],false,false)}</span>`).join(''):'<span class="ph">Tap words to build a sentence</span>'}</div>
      <div class="tiles">${tl.map((t,i)=>`<button class="tile" data-t="${i}" ${bseq.includes(i)?'disabled':''}>${ko(t,false,false)}</button>`).join('')}</div>`;
    foot=`<div class="row"><button class="btn" id="bClr" style="justify-content:center">Clear</button><button class="btn primary" id="bSay" ${bseq.length?'':'disabled'}>Say it</button></div><button class="btn act" id="bLeave">Never mind</button>`;
  }else if(nd.type==='camera'){
    body=`<div class="narr">${esc(nd.en)}</div>`;foot=`<button class="shutter" id="bShut" aria-label="Take photo"></button>`;
  }else if(nd.type==='photo'){
    body=`<svg class="photo" viewBox="0 0 300 220">${photoArt()}</svg><div class="narr">${esc(nd.en)}</div>`;
    foot=`<button class="btn primary" id="bNext">Continue</button>`;
  }else if(nd.type==='card'){
    body=`<div class="en" style="margin:auto;text-align:center">Sound on. Tap any underlined word to see a picture of it.</div>`;foot=`<button class="btn primary" id="bNext">Begin</button>`;
  }else{
    const c=ST.cast[nd.who]||{};
    if(nd.who==='narr')body=nd.en?`<div class="narr">${esc(nd.en)}</div>`:'';
    else if(nd.who==='sign')body=`<div class="koline sign">${ko(nd.ko)}</div><div class="who"><button class="say" data-say>▶ Read aloud</button></div>${nd.en?`<div class="en">${esc(nd.en)}</div>`:''}`;
    else{
      const face=c.look?portrait(c.look,nd.ex):speakerGlyph();
      const anim=revealFor!==S.node?nd.ex:'';
      body=`<div class="line"><div class="spk"><div class="pt ${anim}" style="--cbg:${c.c||'#888'}">${face}</div><div class="seal">${esc(c.n||'')}</div></div>
        <div class="talk"><div class="koline ${nd.who==='bus'?'led':''}">${ko(nd.ko)}</div><button class="say" data-say aria-label="Hear it again">▶ Again</button></div></div>
        ${nd.en?`<div class="en">${esc(nd.en)}</div>`:''}`;
    }
    if(nd.ch)foot=`<div class="acts">${nd.ch.map((x,i)=>`<button class="btn ${x.ko?'ko':'act'}" data-ch="${i}">${x.ko?`<span class="qm">“</span>${ko(x.ko,false,false)}`:esc(x.en)}</button>`).join('')}</div>`;
    else foot=`<button class="btn primary" id="bNext">${nd.next?'Continue':'Look around'}</button>`;
  }
  sb.innerHTML=body;sf.innerHTML=foot;sb.scrollTop=0;setBusy(busy);
  // word-by-word reveal, only the first time a beat appears
  if(nd&&revealFor!==S.node){revealFor=S.node;const k=sb.querySelector('.koline,.narr');const ms=reveal(k);revealUntil=Date.now()+ms;
    const en=sb.querySelector('.en');if(en){en.classList.add('rv');en.style.animationDelay=Math.min(ms,1400)+'ms'}}
  sf.querySelectorAll('[data-hs]').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  sf.querySelectorAll('[data-ch]').forEach(b=>b.onclick=()=>choose(nd.ch[+b.dataset.ch]));
  const bn=$('#bNext');if(bn)bn.onclick=next;
  const bs=sb.querySelector('[data-say]');if(bs)bs.onclick=()=>{sfx('tap');speak(nd.ko,nd.who)};
  sb.querySelectorAll('[data-t]').forEach(b=>b.onclick=()=>{sfx('tap');bseq.push(+b.dataset.t);speak(nd.tiles[+b.dataset.t],'you');render()});
  if($('#bClr'))$('#bClr').onclick=()=>{bseq=[];render()};
  if($('#bLeave'))$('#bLeave').onclick=()=>{S.node=null;save();render()};
  if($('#bSay'))$('#bSay').onclick=()=>say(nd);
  if($('#bShut'))$('#bShut').onclick=()=>{sfx('tap');const f=$('#flash');f.classList.remove('go');void f.offsetWidth;f.classList.add('go');setTimeout(()=>go(nd.next),500)};
  dots();save();
}
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
}

/* tap anywhere on the paper to finish the line, then to continue */
document.addEventListener('click',e=>{
  const sb=e.target.closest('#sb');if(!sb||e.target.closest('button,textarea,a'))return;
  if(Date.now()<revealUntil){sb.querySelectorAll('.rv').forEach(x=>x.style.animationDelay='0ms');revealUntil=0;return}
  const bn=$('#bNext');if(bn)bn.click();
});
/* word taps anywhere: open the picture */
document.addEventListener('click',e=>{const b=e.target.closest('.w,[data-w]');if(b&&b.dataset.w){e.stopPropagation();sfx('tap');
  if(b.closest('#sb'))flashGlow(b.dataset.w);wordSheet(b.dataset.w)}},true);

/* ---------- overlays ---------- */
function overlay(html,cls=''){sfx('open');const o=document.createElement('div');o.className='ov '+cls;o.innerHTML=html;o.addEventListener('click',e=>{if(e.target===o)close(o)});$('#ovs').appendChild(o);return o}
function close(o){o.remove();render()}
function closeTop(){const o=$('#ovs').lastElementChild;if(o)close(o)}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeTop()});
const head=(t,paper)=>`<div class="ph-head"><h2>${t}</h2><button class="x" aria-label="Close">×</button></div>`;

function wordSheet(id){
  const d=W[id];if(!d)return;const r=wrec(id);S.nb[id]=1;save();
  const o=overlay(`<div class="panel paper" role="dialog" aria-label="${esc(id)}">${head('수첩')}<div class="ph-body" id="wsb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const st=status(id);
  const badge=st==='learned'?`<span class="badge" style="color:var(--celadon)">Figured out</span>`:st==='gram'?`<span class="badge" style="color:var(--paper-mute)">Grammar piece</span>`:`<span class="badge" style="color:var(--ochre)">New word</span>`;
  const ctx=r.ctx.slice(-4).reverse().map(l=>{const t=plain(l);const k=id.includes('/')?null:id;
    return `<div class="ctx">${k?t.split(k).map(esc).join(`<mark>${esc(k)}</mark>`):esc(t)}</div>`}).join('')||'<div class="empty">Not seen anywhere yet.</div>';
  o.querySelector('#wsb').innerHTML=`<div class="wordhead">${d.g?'':iconSVG(d.p,'bigicon')}<div style="display:flex;flex-direction:column;gap:8px;min-width:0"><div class="bigword">${esc(id)}</div><div>${badge}</div></div></div>
    <button class="btn" id="wsay" style="justify-content:center">▶ Hear it</button>
    <div class="label">Where you've seen it</div>${ctx}
    <div class="label">Your own note</div><textarea id="wnote" placeholder="Write what you think it means, in your own words.">${esc(r.note||'')}</textarea>`;
  o.querySelector('#wsay').onclick=()=>speak(id,'word');
  o.querySelector('#wnote').oninput=e=>{r.note=e.target.value;save()};
  speak(id,'word');
}

let nbTab='all';
function notebook(){
  Object.keys(S.w).forEach(id=>S.nb[id]=1);save();
  const o=overlay(`<div class="panel">${head('수첩')}<div class="ph-body" id="nbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const draw=()=>{
    const ids=Object.keys(S.w).filter(id=>W[id]);
    const vocab=ids.filter(id=>!W[id].g),gram=ids.filter(id=>W[id].g);
    const learned=vocab.filter(id=>status(id)==='learned').length;
    const list=nbTab==='all'?vocab:nbTab==='todo'?vocab.filter(id=>status(id)!=='learned'):vocab.filter(id=>status(id)==='learned');
    const pat=ST.patterns[0];
    let inner=`<div class="tabs">${[['all','All words'],['todo','Still figuring out'],['learned','Figured out'],['gram','Grammar'],['pat','Patterns']].map(([k,t])=>`<button class="tab ${nbTab===k?'on':''}" data-tab="${k}">${t}</button>`).join('')}</div>
      <div class="label">${learned} figured out · ${vocab.length} seen</div>`;
    if(nbTab==='gram')inner+=gram.length?`<div class="grid">${gram.map(id=>`<button class="card" data-w="${esc(id)}"><span class="k">${esc(id)}</span><span class="tag">grammar</span></button>`).join('')}</div>`:`<div class="empty">Particles and endings you spot will collect here.</div>`;
    else if(nbTab==='pat'){
      if(!pat||!F.pattern)inner+=`<div class="empty">Nothing yet. Keep listening to how people talk about what already happened.</div>`;
      else inner+=`<div class="q"><div class="qt">${esc(pat.title)}</div><div class="why">${esc(pat.note)}</div>
        ${pat.pairs.filter(p=>S.w[p[1]]).map(p=>`<div style="font-family:var(--f-ko);font-size:1.3rem">${esc(p[0])} <span style="color:var(--mist)">→</span> <button class="w ${status(p[1])}" data-w="${esc(p[1])}" style="color:var(--celadon-lt)">${esc(p[1])}</button></div>`).join('')}</div>`;
    }
    else inner+=list.length?`<div class="grid">${list.map(id=>{const st=status(id);return`<button class="card ${st}" data-w="${esc(id)}"><span class="ic">${st==='learned'?iconSVG(W[id].p):'?'}</span><span class="k">${esc(id)}</span><span class="tag">${st==='learned'?'figured out':'new'}</span></button>`}).join('')}</div>`:`<div class="empty">Nothing here yet.</div>`;
    o.querySelector('#nbb').innerHTML=inner;
    o.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{nbTab=b.dataset.tab;draw()});
  };
  draw();
  o.addEventListener('click',()=>setTimeout(()=>{if(document.body.contains(o))draw()},50));
}

function showLog(){
  const o=overlay(`<div class="panel paper">${head('기록')}<div class="ph-body" id="hb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const rows=S.log.map((e,i)=>{
    if(e.who==='narr')return`<div class="hl narr-row">${esc(e.en)}</div>`;
    const c=ST.cast[e.who]||{};const you=e.who==='you';
    const face=you?'':c.look?portrait(c.look,e.ex):e.who==='sign'?'':speakerGlyph();
    return`<div class="hl ${you?'you':''}">${face?`<div class="pt sm" style="--cbg:${c.c||'#888'}">${face}</div>`:''}<div style="min-width:0;flex:1">
      <div class="hn">${esc(you?'You':e.who==='sign'?'Written':c.n||'')}</div><div class="hk">${ko(e.ko,true,false)}</div>${e.en?`<div class="en">${esc(e.en)}</div>`:''}</div>
      <button class="say" data-hi="${i}" aria-label="Hear it">▶</button></div>`}).join('');
  o.querySelector('#hb').innerHTML=rows||'<div class="empty">Nothing yet.</div>';
  o.querySelectorAll('[data-hi]').forEach(b=>b.onclick=()=>{const e=S.log[+b.dataset.hi];speak(e.ko,e.who)});
  const hb=o.querySelector('#hb');hb.scrollTop=hb.scrollHeight;
}

let pickQ=null;
function solveCase(q){
  S.cs[q.id]=1;S.F['solved_'+q.id]=1;learn(q.a,1);
  if(ST.cases.filter(x=>!x.final).every(x=>S.cs[x.id]))S.F.allSolved=1;save();
}
function caseBoard(){
  const o=overlay(`<div class="panel">${head('사건')}<div class="ph-body" id="cbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  const draw=miss=>{
    const qs=ST.cases.filter(q=>cond(q.c));
    const cards=Object.keys(S.w).filter(id=>W[id]&&!W[id].g);
    let h=qs.length?'<div class="empty">Answer each question with a word from your notebook.</div>':'<div class="empty">No questions yet. Look around and see what you can find.</div>';
    h+=qs.map(q=>{
      if(S.cs[q.id])return`<div class="q solved"><div class="qt">${esc(q.q)}</div><div class="ans">${iconSVG(W[q.a]&&W[q.a].p)} ${esc(q.a)}</div><div class="why">${esc(q.why)}</div></div>`;
      return`<div class="q"><div class="qt">${esc(q.q)}</div>${pickQ===q.id?`<div class="pick">${cards.map(id=>`<button class="${status(id)}" data-pk="${esc(id)}">${esc(id)}</button>`).join('')}</div>${miss?`<div class="miss">That doesn't fit the evidence.</div>`:''}`:`<button class="btn-ink" data-open="${q.id}">Pick an answer</button>`}</div>`;
    }).join('');
    o.querySelector('#cbb').innerHTML=h;
    o.querySelectorAll('[data-open]').forEach(b=>b.onclick=()=>{sfx('tap');pickQ=b.dataset.open;draw()});
    o.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>{const q=ST.cases.find(x=>x.id===pickQ);
      if(b.dataset.pk===q.a){solveCase(q);pickQ=null;sfx('solve');buzz([20,40,20]);toast('Solved');draw();
        if(q.final)setTimeout(()=>{close(o);finale()},700);
        else if(S.F.allSolved)toast('Case notes done.');
      }else{sfx('wrong');buzz(60);draw(true)}});
  };
  draw();
}

function openPhone(){
  const o=overlay(`<div class="phone" role="dialog" aria-label="Phone"><div class="ph-status"><span>08:47</span><span>▂▄▆ 42%</span></div><div id="phv" style="flex:1;display:flex;flex-direction:column;min-height:0"></div></div>`,'center');
  const list=()=>{
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><b>메시지</b><button id="pc">Close</button></div><div class="ph-list">${ST.phones.map(t=>`<button class="thr" data-th="${t.id}"><span class="av" style="background:${t.c}">${esc(t.av)}</span><span style="min-width:0;flex:1"><div class="nm">${esc(t.name)}</div><div class="pv">${esc(plain(t.m[t.m.length-1].ko||''))}</div></span>${S.F['read_'+t.id]?'':'<span class="new"></span>'}</button>`).join('')}</div>`;
    o.querySelector('#pc').onclick=()=>close(o);
    o.querySelectorAll('[data-th]').forEach(b=>b.onclick=()=>{sfx('tap');thread(ST.phones.find(t=>t.id===b.dataset.th))});
  };
  const thread=t=>{
    runFx(t.fx);S.F['read_'+t.id]=1;
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><button id="pb">‹ Back</button><b>${esc(t.name)}</b></div><div class="msgs">${t.m.map((m,i)=>m.d?`<div class="day">${ko(m.d)}</div>`:m.sys?`<div class="bub sys">${esc(m.ko)}</div>`:`<div class="bub ${m.me?'me':''}" data-bi="${i}">${ko(m.ko)}<small>${m.t} · tap to hear</small></div>`).join('')}${t.note?`<div class="ph-note">${esc(t.note)}</div>`:''}</div>`;
    o.querySelectorAll('[data-bi]').forEach(b=>b.onclick=()=>speak(t.m[+b.dataset.bi].ko,'sign'));
    o.querySelector('#pb').onclick=list;save();dots();
  };
  S.F.phoneSeen=1;list();
}

function hint(){const h=ST.hints.find(x=>cond(x.c));sfx('tap');if(h)toast(esc(h.t),5200)}

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
      <button class="btn-ink" id="tv">▶ Test voice</button>
      <button class="btn-ink" id="rs" style="color:#e59a87">${confirmReset?'Tap again to erase all progress':'Start over'}</button>`;
    o.querySelectorAll('[data-k]').forEach(b=>b.onclick=()=>{S.set[b.dataset.k]=+b.dataset.v;save();sfx('tap');draw();document.documentElement.dataset.size=S.set.size});
    o.querySelector('#tv').onclick=()=>speak('{안녕하세요}!','sujin');
    o.querySelector('#rs').onclick=()=>{if(!confirmReset){confirmReset=true;draw()}else{S=fresh();S.loc=ST.meta['start-place'];save();o.remove();title()}};
  };draw();
}

function finale(){
  const vocab=Object.keys(S.w).filter(id=>W[id]&&!W[id].g);const got=vocab.filter(id=>status(id)==='learned');
  const o=overlay(`<div class="panel paper">${head(esc(ST.meta['end-title']||''))}<div class="ph-body">
    <div class="narr">${esc(ST.meta['end-text']||'')}</div>
    <div><div class="stat"><span>Words figured out</span><b>${got.length}</b></div><div class="stat"><span>Words still a mystery</span><b>${vocab.length-got.length}</b></div></div>
    <button class="btn primary" id="fin">Keep exploring</button></div></div>`,'center');
  o.querySelector('.x').onclick=()=>close(o);o.querySelector('#fin').onclick=()=>close(o);
}

function toast(h,ms=2600){const t=document.createElement('div');t.className='toast';t.innerHTML=h;$('#toasts').appendChild(t);setTimeout(()=>t.remove(),ms)}

function title(){
  const has=!!S.F.started,m=ST.meta;
  const o=document.createElement('div');o.className='title';
  o.innerHTML=`<div class="art"><svg viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice">${artGateInner(false)}</svg><div class="amb">${ambientHTML('motes')}</div></div>
    <h1>${esc(m.title||'')}</h1><div class="vil">${esc(m.village||'')}</div><p>${esc(m.blurb||'')}</p>
    <div class="acts">${has?'<button class="btn primary" id="tc">Continue</button>':''}<button class="btn ${has?'':'primary'}" id="tn">${has?'New game':'Start the prologue'}</button></div>
    <div class="fine">Turn your sound on.</div>`;
  document.body.appendChild(o);
  if(has)o.querySelector('#tc').onclick=()=>{sfx('page');o.remove();lastLoc=null;render()};
  o.querySelector('#tn').onclick=()=>{sfx('page');S=fresh();S.F.started=1;S.loc=m['start-place'];lastLoc=S.loc;o.remove();go(m.start)};
}

/* ---------- boot ---------- */
async function boot(){
  try{
    let st=null;
    for(const f of STORY_FILES){const r=await fetch(f,{cache:'no-cache'});if(!r.ok)throw new Error(f);st=parseStory(await r.text(),st)}
    ST=st;W=ST.words;
  }catch(e){$('#boot').textContent='Could not load the story.';return}
  load();
  if(!S.loc||!ST.places[S.loc])S.loc=ST.meta['start-place'];
  if(S.node&&!ST.nodes[S.node])S.node=null;
  revealFor=S.node;lastLoc=S.loc;
  $('#boot').remove();
  $('#bNote').onclick=notebook;$('#bCase').onclick=caseBoard;$('#bLog').onclick=showLog;$('#bHint').onclick=hint;$('#bSet').onclick=settings;
  render();title();
}
boot();
if('serviceWorker' in navigator&&location.protocol==='https:'&&!/claude\.ai|claudeusercontent/.test(location.host)){
  navigator.serviceWorker.register('sw.js').catch(()=>{});
}
