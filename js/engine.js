/* ============ ENGINE ============
   Reads story/*.story and runs it. Nothing about the plot lives in this file. */

let WORLD=null;       // story/world.story: cast, words, chapters, map, grammar
let CH={};            // chapter id -> parsed chapter file
let ST=null;          // the current chapter, merged with the world
let W={};             // every word in every chapter -> {p: picture spec, g: grammar, def}

/* ---------- story parser ---------- */
function parseStory(src,st){
  st=st||{cast:{},words:{},places:{},nodes:{},cases:[],phones:[],hints:[],patterns:[],meta:{},chapters:[],map:[],grammar:{},endings:[]};
  let sec=null,cur=null,scene=null,last=null,count=0;
  const node=n=>{count++;const id=count===1?scene:scene+'.'+count;
    if(last&&!last.next&&!last.rewind&&!last.ch&&!last.ans)last.next=id;
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
      case 'chapters':{const [id,t,sub,file]=line.split('|').map(s=>(s||'').trim());st.chapters.push({id,t,sub,file});break}
      case 'map':{m=line.match(/^pin\s+(\S+)\s+([\d.]+)\s+([\d.]+)/);if(m)st.map.push({p:m[1],x:+m[2],y:+m[3]});break}
      case 'words':{m=line.match(/^(.+?)\s*=\s*(.+)$/);if(m)st.words[m[1]]=m[2]==='(grammar)'?{g:1}:{p:m[2]};break}
      case 'grammar':{const i=line.indexOf('|');if(i>0)st.grammar[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      case 'endings':{const i=line.indexOf('|');if(i>0)st.endings.push({k:line.slice(0,i).trim(),d:line.slice(i+1).trim()});break}
      case 'hints':{m=line.match(/^if\s+(\S+):\s*(.+)$/);st.hints.push(m?{c:m[1],t:m[2]}:{t:line});break}
      case 'case':{m=line.match(/^(\w+)\s+(\S+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        if(m)st.cases.push({id:m[1],a:m[2],final:!!m[3],c:m[4],q:m[5],why:m[6]});break}
      case 'pattern':{if(m=line.match(/^title\s+(.+)/))cur.title=m[1];else if(m=line.match(/^note\s+(.+)/))cur.note=m[1];
        else if(m=line.match(/^need\s+(\d+)/))cur.need=+m[1];else if(m=line.match(/^(.+?)\s*>\s*(.+)$/))cur.pairs.push([m[1],m[2]]);break}
      case 'place':{
        if(m=line.match(/^(name|sub|art|first|always|ambient|travel)\s+(.+)$/))cur[m[1]]=m[2];
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
        else if(m=line.match(/^<-\s*(.+)$/)){if(last)last.rewind=m[1].trim()}
        else if(m=line.match(/^@build\s+(.+)$/))node({type:'build',en:m[1],tiles:[],ans:[]});
        else if(m=line.match(/^tiles:\s*(.+)$/))last.tiles=m[1].split('|').map(s=>s.trim());
        else if(m=line.match(/^answer:\s*(.+?)\s+->\s+(.+)$/))last.ans.push([m[1].split('|').map(s=>s.trim()),m[2].trim()]);
        else if(m=line.match(/^miss\s+->\s+(.+)$/))last.miss=m[1].trim();
        else if(m=line.match(/^@camera\s+(?:([\d.]+)\s+([\d.]+)\s*\|\s*)?(.+)$/))node({type:'camera',tx:+(m[1]||50),ty:+(m[2]||50),en:m[3]});
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
// Per-chapter progress lives in loc/node/F/cs/visited (swapped in and out of S.prog by chapter).
// Everything else (notebook, map, settings, finished chapters) is shared.
const KEY='tal-save-v2';
const fresh=()=>({ch:null,prog:{},done:{},known:{},loc:null,node:null,F:{},w:{},cs:{},nb:{},log:[],set:{auto:1,slow:0,glow:1,sound:1,size:1,dev:0},visited:{}});
const CH_FIELDS=['loc','node','F','cs','visited'];
// erasing progress keeps what you wrote about each word (for playtesting)
function freshKeepNotes(){const old=S;const n=fresh();n.set=old.set;
  Object.entries(old.w||{}).forEach(([id,r])=>{if(r&&r.note&&r.note.trim())n.w[id]={ctx:[],note:r.note,sure:r.sure||0,n:1}});return n}
let S=fresh();
function load(){try{const r=localStorage.getItem(KEY);if(r){S=Object.assign(fresh(),JSON.parse(r));S.set=Object.assign(fresh().set,S.set);return true}}catch(e){}return false}
function save(){try{localStorage.setItem(KEY,JSON.stringify(S))}catch(e){}}
const F=new Proxy({},{get:(t,k)=>S.F[k],set:(t,k,v)=>{S.F[k]=v;return true}});
// "allSolved" is worked out live: every case question you can currently see (except the last one) is answered
const caseReadyNow=()=>!!ST&&ST.cases.filter(q=>!q.final&&cond(q.c)).every(q=>S.cs[q.id]);
function cond(c){if(!c)return true;return c.split('&').every(t=>{t=t.trim();
  const neg=t.startsWith('!');if(neg)t=t.slice(1);
  let v=t.startsWith('@')?S.loc===t.slice(1):t==='allSolved'?caseReadyNow():!!S.F[t];
  return neg?!v:v})}
function tgt(t){const m=String(t).match(/^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$/);return m?(cond(m[1])?m[2]:m[3]):String(t).trim()}

/* ---------- tokens & words ---------- */
// Word colors come from YOUR notebook, not from the game:
//   new   = first time you've run into it     seen  = met before, no note yet
//   guess = you wrote a meaning, not sure     sure  = you ticked "I'm sure"
const TOK=/\{([^}|]+)(?:\|([^}]+))?\}/g;
const plain=s=>String(s).replace(TOK,'$1');
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const idsIn=s=>[...String(s).matchAll(TOK)].map(m=>m[2]||m[1]);
function wrec(id){return S.w[id]||(S.w[id]={ctx:[],note:''})}
function see(id,line){if(!W[id])return;const r=wrec(id);if(!r.ctx.includes(line)){r.ctx.push(line);if(r.ctx.length>6)r.ctx.shift();r.n=(r.n||0)+1}}
function status(id){const d=W[id];if(!d)return'seen';if(d.g)return'gram';const r=S.w[id];if(!r)return'new';
  if(r.note&&r.note.trim())return r.sure?'sure':'guess';return (r.n||0)<=1?'new':'seen'}
function ko(str,tap=true,mark=true){
  return esc(str).replace(TOK,(m,surf,id)=>{id=id||surf;if(mark)see(id,str);
    return tap?`<button class="w ${status(id)}" data-w="${id}">${surf}</button>`:surf}).replace(/\n/g,'<br>');
}
function learn(){} // kept so old story effects ("learn X") are harmless: you decide what you know now
function checkPattern(){const p=ST.patterns[0];if(!p||F.pattern)return;
  if(p.pairs.filter(x=>S.w[x[1]]).length>=p.need){F.pattern=1;toast('Pattern spotted. Check the Patterns tab in your notebook.')}}

/* ---------- voice (Web Audio, so phones don't show a media-player notification) ---------- */
let VOICE=null,SRC=null,TOKEN=0;const BUF={};
function pickVoice(){const vs=speechSynthesis.getVoices();VOICE=vs.find(v=>/^ko/i.test(v.lang)&&/google/i.test(v.name))||vs.find(v=>/^ko/i.test(v.lang))||null}
if('speechSynthesis' in window){pickVoice();speechSynthesis.onvoiceschanged=pickVoice}
// must match normalize() in tools/build_audio.py
const normT=s=>plain(s).replace(/[📸🏮^♡✖📞🔔💙]/gu,'').replace(/\//g,', ').replace(/\s+/g,' ').trim();
const vg=who=>ST&&ST.cast[who]&&ST.cast[who].voice?who:'sign';
const clipFor=(text,who)=>window.AUDIO&&window.AUDIO[vg(who)+'|'+normT(text)];
async function buffer(url){if(BUF[url])return BUF[url];const c=ac();const ab=await(await fetch(url)).arrayBuffer();
  const b=await new Promise((res,rej)=>c.decodeAudioData(ab,res,rej));BUF[url]=b;return b}
function stopAudio(){TOKEN++;if(SRC){try{SRC.onended=null;SRC.stop()}catch(e){}SRC=null}if('speechSynthesis' in window)speechSynthesis.cancel()}
// Resolves when the line finishes (or after 8s at most), so callers can wait for it.
function speak(text,who){
  stopAudio();const my=TOKEN;
  return new Promise(async done=>{
    const t=normT(text);if(!t)return done();
    const cap=setTimeout(done,8000),fin=()=>{clearTimeout(cap);done()};
    const f=clipFor(text,who);
    if(f){try{const b=await buffer(f);if(my!==TOKEN)return fin();const c=ac();
      const s=c.createBufferSource();s.buffer=b;s.playbackRate.value=S.set.slow?.82:1;s.connect(c.destination);
      s.onended=()=>{if(SRC===s)SRC=null;fin()};SRC=s;s.start();return}catch(e){}}
    if(my!==TOKEN)return fin();tts(t,fin);
  });
}
// a sentence you built: one recording if it exists, otherwise your voice saying each piece
async function speakBuilt(tiles,line){
  if(clipFor(line,'you'))return speak(line,'you');
  for(const t of tiles){const p=speak(t,'you');const my=TOKEN;await p;if(TOKEN!==my)return}
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
  tap:()=>{tone(1400,0,.045,'sine',.05);noise(0,.025,.05,2600)},
  page:()=>noise(0,.16,.05,1600),
  open:()=>noise(0,.1,.04,900),
  learn:()=>{tone(784,0,.55,'triangle',.1);tone(1175,.09,.7,'triangle',.08)},
  solve:()=>[523,659,784,1047].forEach((f,i)=>tone(f,i*.08,.8,'triangle',.08)),
  wrong:()=>tone(140,0,.22,'sine',.12),
  rewind:()=>{const c=ac();if(!c)return;const o=c.createOscillator(),g=c.createGain(),t=c.currentTime;o.type='sawtooth';
    o.frequency.setValueAtTime(900,t);o.frequency.exponentialRampToValueAtTime(180,t+.5);g.gain.setValueAtTime(.04,t);g.gain.exponentialRampToValueAtTime(.0001,t+.55);
    o.connect(g).connect(c.destination);o.start(t);o.stop(t+.6)}
};
function sfx(n){if(!S.set.sound)return;try{SFX[n]&&SFX[n]()}catch(e){}}
function buzz(p){if(S.set.sound&&navigator.vibrate)try{navigator.vibrate(p)}catch(e){}}

/* ---------- flow ---------- */
const $=s=>document.querySelector(s);
let bseq=[],busy=false,glowFor=null,revealFor=null,revealUntil=0,artKey=null,ambKey=null,lastLoc=null,quiet=false,cam={x:28,y:30};
let BACK=[];const SEEN=new Set();   // lines you can step back to in the current scene; beats already shown
function runFx(list,replay){(list||[]).forEach(e=>{if(e.c&&!cond(e.c))return;const a=e.a;
  if(replay&&e.k==='toast')return;
  if(e.k==='set')a.split(',').forEach(f=>S.F[f.trim()]=1);
  else if(e.k==='unset')a.split(',').forEach(f=>delete S.F[f.trim()]);
  else if(e.k==='place')S.loc=a;
  else if(e.k==='led')S.F.led=a;
  else if(e.k==='toast')toast(esc(a),5000);
})}
function logLine(e){S.log.push(e);if(S.log.length>80)S.log.shift()}
function enter(place){
  S.loc=place;const l=ST.places[place];S.node=null;BACK=[];
  if(l.always){go(l.always);return}
  if(l.first&&!S.visited[place]){S.visited[place]=1;go(l.first);return}
  S.visited[place]=1;save();render();
}
function go(id){
  id=tgt(id);const nd=ST.nodes[id];if(!nd){console.warn('no scene',id);S.node=null;BACK=[];save();render();return}
  if(S.node&&S.node!==id){BACK.push({id:S.node,loc:S.loc});if(BACK.length>60)BACK.shift()}
  const replay=SEEN.has(id);SEEN.add(id);
  S.node=id;bseq=[];runFx(nd.fx,replay);checkPattern();
  if(nd.type==='camera')cam={x:22+Math.random()*10,y:24+Math.random()*10};
  if(nd.ko||(nd.who==='narr'&&nd.en))logLine({who:nd.who,ex:nd.ex,ko:nd.ko,en:nd.en});
  save();render();
  if(S.set.auto&&nd.ko&&!quiet)speak(nd.ko,nd.who);
}
function next(){
  sfx('page');const nd=ST.nodes[S.node];
  if(nd&&nd.rewind){rewindTo(nd.rewind);return}
  if(nd&&nd.next)go(nd.next);else{S.node=null;BACK=[];save();render()}
}
// step back one line in the current scene (like a visual novel's back button)
function goBack(){
  if(busy||!BACK.length)return;const p=BACK.pop();stopAudio();sfx('page');
  S.node=p.id;S.loc=p.loc;bseq=[];revealFor=p.id;glowFor=p.id;save();render();
  const nd=ST.nodes[p.id];if(S.set.auto&&nd&&nd.ko)speak(nd.ko,nd.who);
}
// wrong turns: play the rewind effect, then put you back at the decision
function rewindTo(t){
  stopAudio();sfx('rewind');buzz(30);
  const sc=$('#scene');sc.classList.add('rewinding');
  $('#fx').insertAdjacentHTML('beforeend',`<div class="rewind-badge">⏪</div>`);
  setBusy(true);
  setTimeout(()=>{sc.classList.remove('rewinding');setBusy(false);go(t)},900);
}
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
  await speakBuilt(words,line);await new Promise(r=>setTimeout(r,250));
  setBusy(false);go(hit?hit[1]:nd.miss);
}
function spot(i){const x=ST.places[S.loc].spots[i];if(!x)return;sfx('tap');
  if(x.kind==='->')go(x.t);else if(x.t==='phone')openPhone();else{const m=x.t.match(/^place\s+(\S+)/);if(m)enter(m[1])}}
// playtest: jump ahead to the next decision without the voices
function skipAhead(){
  quiet=true;stopAudio();let n=0;
  while(S.node&&n++<60){const nd=ST.nodes[S.node];
    if(nd.ch||nd.type==='build'||nd.type==='camera')break;
    if(nd.rewind){go(nd.rewind);continue}
    if(nd.next)go(nd.next);else{S.node=null;save();render();break}}
  quiet=false;
}

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
const canTravel=()=>{const l=ST.places[S.loc];return !S.node&&!!l&&l.travel!=='no'};
const hasPhone=()=>!!S.F.hasPhone&&ST.phones.length>0;

/* ---------- render ---------- */
function render(){
  const l=ST.places[S.loc]||Object.values(ST.places)[0];const nd=S.node?ST.nodes[S.node]:null;
  document.documentElement.dataset.size=S.set.size;
  $('#locKo').textContent=l.name||'';$('#locSub').textContent=l.sub||'';
  if(S.loc)S.known[S.loc]=1;
  $('#bPhone').hidden=!hasPhone();
  const ak=l.art+(l.art==='bus'?'|'+(S.F.led||''):'');
  if(ak!==artKey){const w=$('#art');w.innerHTML=(ART[l.art]||ART.madang)();w.classList.remove('in');void w.offsetWidth;w.classList.add('in');artKey=ak}
  const amb=l.ambient||'none';if(amb!==ambKey){$('#amb').innerHTML=ambientHTML(amb);ambKey=amb}
  let h='';
  if(nd&&nd.type==='camera')h+=`<div class="vf" id="vf" style="left:${cam.x}%;top:${cam.y}%"><span>Drag me</span></div>`;
  if(nd&&nd.type==='card')h+=`<div class="card-title"><b>${esc(nd.title)}</b>${nd.sub?`<span>${esc(nd.sub)}</span>`:''}</div>`;
  if(!nd)l.spots.forEach((x,i)=>{if(!cond(x.c))return;h+=`<button class="hs" data-hs="${i}" style="left:${x.x}%;top:${x.y}%" aria-label="${esc(x.l)}"><i></i><span>${esc(x.l)}</span></button>`});
  if(nd&&nd.ko&&glowFor!==S.node){glowFor=S.node;h+=glowHTML(idsIn(nd.ko))}
  if(S.loc!==lastLoc&&!(nd&&nd.type==='card'))h+=`<div class="placecard"><b>${esc(l.name||'')}</b><span>${esc(l.sub||'')}</span></div>`;
  lastLoc=S.loc;
  h+=`<div class="flash" id="flash"></div>`;
  $('#fx').innerHTML=h;
  $('#fx').querySelectorAll('.hs').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  if(nd&&nd.type==='camera')dragFrame($('#vf'));
  const sb=$('#sb'),sf=$('#sf');let body='',foot='';
  const devSkip=S.set.dev&&nd&&!nd.ch&&nd.type!=='build'?`<button class="btn dev" id="bSkip">⏭ Skip to next decision</button>`:'';
  const backBtn=nd&&BACK.length?`<button class="btn back" id="bBack" aria-label="Back one line">‹ Back</button>`:'';
  const cont=label=>`<div class="controw">${backBtn}<button class="btn primary" id="bNext">${label}</button></div>`;
  if(!nd){
    const d=l.desc.find(x=>cond(x.c));
    const chips=l.spots.map((x,i)=>cond(x.c)?`<button class="chipbtn" data-hs="${i}">${esc(x.l)}</button>`:'').join('');
    const mapBtn=canTravel()&&ST.map.filter(p=>S.known[p.p]&&ST.places[p.p]).length>1?`<button class="chipbtn mapchip" id="bMap">Village map</button>`:'';
    body=`<div class="narr">${esc(d?d.t:'')}</div><div class="chips">${chips}${mapBtn}</div>`;
  }else if(nd.type==='build'){
    const tl=nd.tiles;
    body=`<div class="en">${esc(nd.en)}</div><div class="built">${bseq.length?bseq.map(i=>`<span>${ko(tl[i],false,false)}</span>`).join(''):'<span class="ph">Tap words to build a sentence</span>'}</div>
      <div class="tiles">${tl.map((t,i)=>`<button class="tile" data-t="${i}" ${bseq.includes(i)?'disabled':''}>${ko(t,false,false)}</button>`).join('')}</div>`;
    foot=`<div class="row"><button class="btn" id="bClr" style="justify-content:center">Clear</button><button class="btn primary" id="bSay" ${bseq.length?'':'disabled'}>Say it</button></div><div class="controw">${backBtn}<button class="btn act" id="bLeave">Never mind</button></div>`;
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
        <div class="talk"><div class="koline ${nd.who==='bus'?'led':''}">${ko(nd.ko)}</div><button class="say" data-say aria-label="Hear it again">▶ Again</button></div></div>
        ${nd.en?`<div class="en">${esc(nd.en)}</div>`:''}`;
    }
    if(nd.ch)foot=`<div class="acts">${nd.ch.map((x,i)=>`<button class="btn ${x.ko?'ko':'act'}" data-ch="${i}">${x.ko?`<span class="qm">“</span>${ko(x.ko,false,false)}`:esc(x.en)}</button>`).join('')}</div>${backBtn?`<div class="controw">${backBtn}</div>`:''}`;
    else foot=`${cont(nd.next||nd.rewind?'Continue':'Look around')}${devSkip}`;
  }
  sb.innerHTML=body;sf.innerHTML=foot;sb.scrollTop=0;setBusy(busy);
  if(nd&&revealFor!==S.node){revealFor=S.node;const k=sb.querySelector('.koline,.narr');const ms=reveal(k);revealUntil=Date.now()+ms;
    const en=sb.querySelector('.en');if(en){en.classList.add('rv');en.style.animationDelay=Math.min(ms,1400)+'ms'}}
  document.querySelectorAll('#sb [data-hs],#sf [data-hs]').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  sf.querySelectorAll('[data-ch]').forEach(b=>b.onclick=()=>choose(nd.ch[+b.dataset.ch]));
  const bn=$('#bNext');if(bn)bn.onclick=next;
  if($('#bSkip'))$('#bSkip').onclick=skipAhead;
  if($('#bMap'))$('#bMap').onclick=openMap;
  if($('#bBack'))$('#bBack').onclick=goBack;
  const bs=sb.querySelector('[data-say]');if(bs)bs.onclick=()=>{sfx('tap');speak(nd.ko,nd.who)};
  sb.querySelectorAll('[data-t]').forEach(b=>b.onclick=()=>{sfx('tap');bseq.push(+b.dataset.t);speak(nd.tiles[+b.dataset.t],'you');render()});
  if($('#bClr'))$('#bClr').onclick=()=>{bseq=[];render()};
  if($('#bLeave'))$('#bLeave').onclick=()=>{S.node=null;BACK=[];save();render()};
  if($('#bSay'))$('#bSay').onclick=()=>say(nd);
  if($('#bShut'))$('#bShut').onclick=()=>shoot(nd);
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
  $('#phoneDot').hidden=!ST.phones.some(t=>!S.F['read_'+t.id]);
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
/* word taps anywhere: open the notebook page for that word */
document.addEventListener('click',e=>{const b=e.target.closest('.w,[data-w]');if(b&&b.dataset.w){e.stopPropagation();sfx('tap');
  if(b.closest('#sb'))flashGlow(b.dataset.w);wordSheet(b.dataset.w)}},true);

/* ---------- overlays ---------- */
function overlay(html,cls=''){sfx('open');const o=document.createElement('div');o.className='ov '+cls;o.innerHTML=html;o.addEventListener('click',e=>{if(e.target===o)close(o)});$('#ovs').appendChild(o);return o}
function close(o){stopAudio();o.remove();render()}
function closeTop(){const o=$('#ovs').lastElementChild;if(o)close(o)}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeTop()});
const head=t=>`<div class="ph-head"><h2>${t}</h2><button class="x" aria-label="Close">×</button></div>`;
const STATE_LABEL={new:'New word',seen:'No note yet',guess:'Your guess',sure:'You\'re sure',gram:'Grammar piece'};

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
      ${d.g?'':`<div class="label">What you think it means</div><textarea id="wnote" placeholder="Your own words. Nobody checks this.">${esc(r.note||'')}</textarea>
      <label class="surebox"><input type="checkbox" id="wsure" ${r.sure?'checked':''} ${r.note&&r.note.trim()?'':'disabled'}><span>I'm sure about this</span></label>`}
      <div class="label">Where you've seen it</div>${ctx}
      ${d.g?'':`<button class="linkish" id="wsym">What do the badges on the picture mean?</button>`}`;
    o.querySelector('#wsay').onclick=()=>speak(id,'word');
    const n=o.querySelector('#wnote');if(n)n.oninput=e=>{r.note=e.target.value;if(!r.note.trim())r.sure=0;save();
      const c=o.querySelector('#wsure');c.disabled=!r.note.trim();if(!r.note.trim())c.checked=false;o.querySelector('.badge').className='badge st-'+status(id);o.querySelector('.badge').textContent=STATE_LABEL[status(id)]};
    const c=o.querySelector('#wsure');if(c)c.onchange=e=>{r.sure=e.target.checked?1:0;save();sfx(r.sure?'learn':'tap');o.querySelector('.badge').className='badge st-'+status(id);o.querySelector('.badge').textContent=STATE_LABEL[status(id)]};
    const sy=o.querySelector('#wsym');if(sy)sy.onclick=()=>{nbTab='sym';notebook()};
  };
  draw();speak(id,'word');
}

let nbTab='all';
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
    const list=nbTab==='all'?vocab:nbTab==='todo'?vocab.filter(id=>['new','seen'].includes(status(id))):nbTab==='guess'?by('guess'):by('sure');
    const pat=ST.patterns[0];
    const tabs=[['all','All'],['todo','No note'],['guess','Guesses'],['sure','Sure'],['gram','Grammar'],['pat','Patterns'],['sym','Symbols']];
    let inner=`<div class="tabs">${tabs.map(([k,t])=>`<button class="tab ${nbTab===k?'on':''}" data-tab="${k}">${t}</button>`).join('')}</div>`;
    if(['all','todo','guess','sure'].includes(nbTab))inner+=`<div class="label">${by('sure').length} sure · ${by('guess').length} guesses · ${vocab.length} seen</div>`;
    if(nbTab==='gram'){
      inner+=`<div class="label">Little pieces that stick to words</div>`+(gram.length?`<div class="glist">${gram.map(id=>`<button class="grow" data-w="${esc(id)}"><b>${esc(id)}</b><span>${esc(WORLD.grammar[id]||'')}</span></button>`).join('')}</div>`:`<div class="empty">The ones you run into will collect here.</div>`);
      inner+=`<div class="label">Endings</div><div class="glist">${WORLD.endings.map(e=>`<div class="grow"><b>${esc(e.k)}</b><span>${esc(e.d)}</span></div>`).join('')}</div>`;
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
const normAns=s=>String(s).replace(/[\s.?!~,·]/g,'');
function caseBoard(){
  const o=overlay(`<div class="panel">${head('사건')}<div class="ph-body" id="cbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let filter='',miss=false;
  const tryAnswer=(q,val)=>{
    if(normAns(val)===normAns(q.a)){S.cs[q.id]=1;S.F['solved_'+q.id]=1;save();pickQ=null;filter='';miss=false;sfx('solve');buzz([20,40,20]);toast('Solved');draw();
      if(q.final)setTimeout(()=>{close(o);finale()},700);else if(caseReadyNow())toast('Case notes done.');}
    else{sfx('wrong');buzz(60);miss=true;draw()}
  };
  const draw=()=>{
    const qs=ST.cases.filter(q=>cond(q.c));
    const cards=Object.keys(S.w).filter(id=>W[id]&&!W[id].g&&(!filter||id.includes(filter)||(S.w[id].note||'').toLowerCase().includes(filter.toLowerCase())));
    let h=qs.length?'<div class="empty">Answer each question with a word. Type it, or pick it from the words you\'ve seen.</div>':'<div class="empty">No questions yet. Look around and see what you can find.</div>';
    h+=qs.map(q=>{
      if(S.cs[q.id])return`<div class="q solved"><div class="qt">${esc(q.q)}</div><div class="ans">${iconSVG(W[q.a]&&W[q.a].p)} ${esc(q.a)}</div><div class="why">${esc(q.why)}</div></div>`;
      if(pickQ!==q.id)return`<div class="q"><div class="qt">${esc(q.q)}</div><button class="btn-ink" data-open="${q.id}">Answer</button></div>`;
      return`<div class="q"><div class="qt">${esc(q.q)}</div>
        <form class="typeans" id="ta"><input id="ti" lang="ko" autocomplete="off" placeholder="Type in Korean, or search your words" value="${esc(filter)}"><button class="btn-ink" type="submit">Answer</button></form>
        ${miss?`<div class="miss">That doesn't fit the evidence.</div>`:''}
        <div class="pick">${cards.map(id=>`<button class="w ${status(id)}" data-pk="${esc(id)}" data-w="">${esc(id)}</button>`).join('')||'<span class="empty">No matching words.</span>'}</div></div>`;
    }).join('');
    o.querySelector('#cbb').innerHTML=h;
    o.querySelectorAll('[data-open]').forEach(b=>b.onclick=()=>{sfx('tap');pickQ=b.dataset.open;filter='';miss=false;draw();const i=o.querySelector('#ti');if(i)i.focus()});
    const q=ST.cases.find(x=>x.id===pickQ);
    o.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>tryAnswer(q,b.dataset.pk));
    const ti=o.querySelector('#ti');if(ti){ti.oninput=e=>{filter=e.target.value.trim();const pos=e.target.selectionStart;
      const pk=o.querySelector('.pick');const cs=Object.keys(S.w).filter(id=>W[id]&&!W[id].g&&(!filter||id.includes(filter)||(S.w[id].note||'').toLowerCase().includes(filter.toLowerCase())));
      pk.innerHTML=cs.map(id=>`<button class="w ${status(id)}" data-pk="${esc(id)}" data-w="">${esc(id)}</button>`).join('')||'<span class="empty">No matching words.</span>';
      pk.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>tryAnswer(q,b.dataset.pk))}}
    const ta=o.querySelector('#ta');if(ta)ta.onsubmit=e=>{e.preventDefault();tryAnswer(q,o.querySelector('#ti').value)};
  };
  draw();
}

function openPhone(){
  const o=overlay(`<div class="phone" role="dialog" aria-label="Phone"><div class="ph-status"><span>08:47</span><span>▂▄▆ 42%</span></div><div id="phv" style="flex:1;display:flex;flex-direction:column;min-height:0"></div></div>`,'center');
  const list=()=>{
    stopAudio();
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
  list();
}

function menu(){
  const o=overlay(`<div class="panel">${head('메뉴')}<div class="ph-body"><div class="menulist">
    <button class="mi" id="mHint"><span class="mic">💡</span><span><b>Think</b><small>A nudge in the right direction</small></span></button>
    <div class="hintbox" id="hintbox" hidden></div>
    <button class="mi" id="mLog"><span class="mic">💬</span><span><b>What was said</b><small>Scroll back through every line</small></span></button>
    <button class="mi" id="mMap"><span class="mic">🗺️</span><span><b>Village map</b><small>Places you've been</small></span></button>
    <button class="mi" id="mCh"><span class="mic">📖</span><span><b>Chapters</b><small>Continue, replay</small></span></button>
    <button class="mi" id="mSet"><span class="mic"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg></span><span><b>Settings</b><small>Voice, text size, sounds</small></span></button>
  </div></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  o.querySelector('#mHint').onclick=()=>{sfx('tap');const h=ST.hints.find(x=>cond(x.c));const b=o.querySelector('#hintbox');b.textContent=h?h.t:'Look around.';b.hidden=false};
  o.querySelector('#mLog').onclick=()=>{o.remove();showLog()};
  o.querySelector('#mMap').onclick=()=>{o.remove();openMap()};
  o.querySelector('#mCh').onclick=()=>{o.remove();chapterList()};
  o.querySelector('#mSet').onclick=()=>{o.remove();settings()};
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
      <button class="btn-ink" id="rs" style="color:#e59a87">${confirmReset?'Tap again to erase all progress':'Start over'}</button>`;
    o.querySelectorAll('[data-k]').forEach(b=>b.onclick=()=>{S.set[b.dataset.k]=+b.dataset.v;save();sfx('tap');draw();document.documentElement.dataset.size=S.set.size});
    o.querySelector('#tv').onclick=()=>speak('{안녕하세요}!','sujin');
    o.querySelector('#rs').onclick=()=>{if(!confirmReset){confirmReset=true;draw()}else{S=freshKeepNotes();BACK=[];save();o.remove();title()}};
  };draw();
}

/* ---------- chapters ---------- */
function useChapter(id){
  const c=CH[id]||CH[WORLD.chapters[0].id];
  ST={cast:Object.assign({},WORLD.cast,c.cast),words:W,places:c.places,nodes:c.nodes,cases:c.cases,phones:c.phones,hints:c.hints,
    patterns:WORLD.patterns.concat(c.patterns),meta:Object.assign({},WORLD.meta,c.meta),map:WORLD.map,chapters:WORLD.chapters};
}
const chIndex=id=>WORLD.chapters.findIndex(c=>c.id===id);
const chInfo=id=>WORLD.chapters.find(c=>c.id===id)||{};
const chReady=id=>!!CH[id];
const chUnlocked=id=>{const i=chIndex(id);return i===0||!!S.done[WORLD.chapters[i-1].id]};
const chStarted=id=>id===S.ch?!!S.F.started:!!(S.prog[id]&&S.prog[id].F&&S.prog[id].F.started);
function stash(){if(S.ch)S.prog[S.ch]=JSON.parse(JSON.stringify(Object.fromEntries(CH_FIELDS.map(k=>[k,S[k]]))))}
function startChapter(id,restart){
  stash();const p=!restart&&S.prog[id];
  S.ch=id;useChapter(id);artKey=null;ambKey=null;lastLoc=null;BACK=[];if(restart)SEEN.clear();
  if(p&&p.F&&p.F.started){
    CH_FIELDS.forEach(k=>S[k]=p[k]);
    if(!ST.places[S.loc])S.loc=ST.meta['start-place'];if(S.node&&!ST.nodes[S.node])S.node=null;
    revealFor=S.node;save();render();return;
  }
  S.F={started:1};S.cs={};S.visited={};S.node=null;S.loc=ST.meta['start-place'];
  stash();go(ST.meta.start);
}
const nextChapter=()=>WORLD.chapters[chIndex(S.ch)+1]||null;

function finale(){
  S.done[S.ch]=1;stash();save();
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
  const pick=(id,restart)=>{o.remove();const t=document.querySelector('.title');if(t)t.remove();startChapter(id,restart)};
  const draw=()=>{
    o.querySelector('#clb').innerHTML=WORLD.chapters.map(c=>{
      const ready=chReady(c.id),open=ready&&chUnlocked(c.id),done=!!S.done[c.id],started=chStarted(c.id);
      const state=!ready?'Coming soon':!open?'Locked':done?'Finished':started?'In progress':'New';
      let b='';
      if(open){
        if(started&&!done)b+=`<button class="btn-ink" data-go="${c.id}">Continue</button>`;
        if(!started&&!done)b+=`<button class="btn-ink" data-new="${c.id}">Start</button>`;
        if(started||done)b+=confirmId===c.id?`<button class="btn-ink" data-new="${c.id}" style="color:#e59a87">Tap again to start over</button>`:`<button class="btn-ink" data-ask="${c.id}">${done?'Replay':'Start over'}</button>`;
      }
      return `<div class="chrow ${open?'':'locked'} ${c.id===S.ch?'cur':''}"><div class="chn"><b>${esc(c.t)}</b><span>${esc(open||done?c.sub:'?')}</span></div><div class="chs">${state}</div><div class="chb">${b}</div></div>`;
    }).join('')+`<div class="empty">Your notebook and map carry over between chapters. Replaying a chapter starts it from the beginning.</div>`;
    o.querySelectorAll('[data-go]').forEach(x=>x.onclick=()=>pick(x.dataset.go,false));
    o.querySelectorAll('[data-new]').forEach(x=>x.onclick=()=>pick(x.dataset.new,true));
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
    <div class="acts">${has?`<button class="btn primary" id="tc">Continue · ${esc(chInfo(S.ch).t||'')}</button><button class="btn" id="tl">Chapters</button>`:''}<button class="btn ${has?'':'primary'}" id="tn">${has?'New game':'Start'}</button></div>
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

/* ---------- boot ---------- */
async function boot(){
  try{
    const get=async f=>{const r=await fetch('story/'+f,{cache:'no-cache'});if(!r.ok)throw new Error(f+' returned '+r.status);return r.text()};
    WORLD=parseStory(await get('world.story'));CH={};
    for(const c of WORLD.chapters)if(c.file)CH[c.id]=parseStory(await get(c.file));
    W=Object.assign({},WORLD.words,...Object.values(CH).map(c=>c.words));
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
  load();
  if(!S.ch){ // saves from before chapters existed: they were all prologue
    S.ch=WORLD.chapters[0].id;if(S.F.solved_q5)S.done[S.ch]=1;
    Object.keys(S.visited||{}).forEach(p=>S.known[p]=1);if(S.loc)S.known[S.loc]=1;
  }
  if(!CH[S.ch])S.ch=WORLD.chapters[0].id;
  useChapter(S.ch);
  if(!S.loc||!ST.places[S.loc])S.loc=ST.meta['start-place'];
  if(S.node&&!ST.nodes[S.node])S.node=null;
  revealFor=S.node;lastLoc=S.loc;
  $('#boot').remove();
  $('#bNote').onclick=notebook;$('#bCase').onclick=caseBoard;$('#bPhone').onclick=openPhone;$('#bMenu').onclick=menu;
  $('#locKo').onclick=openMap;$('#locSub').onclick=openMap;
  render();title();
}
boot();
if('serviceWorker' in navigator&&location.protocol==='https:'&&!/claude\.ai|claudeusercontent/.test(location.host)){
  navigator.serviceWorker.register('sw.js').catch(()=>{});
}
