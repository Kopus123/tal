/* ============ ENGINE ============
   Reads story/*.story and runs it. Nothing about the plot lives in this file. */

let WORLD=null;       // story/world.story: cast, words, chapters, map, grammar
let CH={};            // chapter id -> parsed chapter file
let ST=null;          // the current chapter, merged with the world
let W={};             // every word in every chapter -> {p: picture spec, g: grammar, def}

/* ---------- story parser ---------- */
function parseStory(src,st){
  st=st||{cast:{},words:{},places:{},nodes:{},cases:[],phones:[],hints:[],patterns:[],meta:{},chapters:[],map:[],grammar:{},endings:[],evidence:{},statements:{},tells:{},examines:{}};
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
      else if(sec==='examine')cur=st.examines[arg]={id:arg,details:[]};
      return}
    let m;
    switch(sec){
      case 'meta':{const i=line.indexOf(' ');st.meta[line.slice(0,i)]=line.slice(i+1).trim();break}
      // every word and line carries a language (meta "lang", default ko); "who@ja: ..." overrides one line
      case 'cast':{const [k,n,c,v,look]=line.split('|').map(s=>s.trim());st.cast[k]={n,c,voice:!!v,look:look||''};break}
      case 'chapters':{const [id,t,sub,file,cont]=line.split('|').map(s=>(s||'').trim());st.chapters.push({id,t,sub,file,cont:!!cont});break}
      case 'map':{m=line.match(/^pin\s+(\S+)\s+([\d.]+)\s+([\d.]+)/);if(m)st.map.push({p:m[1],x:+m[2],y:+m[3]});break}
      case 'words':{m=line.match(/^(.+?)\s*=\s*(.+)$/);if(m)st.words[m[1]]=Object.assign(m[2]==='(grammar)'?{g:1}:{p:m[2]},{lang:st.meta.lang||'ko'});break}
      case 'grammar':{const i=line.indexOf('|');if(i>0)st.grammar[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      // tells: grammar that gives people away. "piece | what it gives away" (shown once you've caught one)
      case 'tells':{const i=line.indexOf('|');if(i>0)st.tells[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      case 'endings':{const i=line.indexOf('|');if(i>0)st.endings.push({k:line.slice(0,i).trim(),d:line.slice(i+1).trim()});break}
      case 'hints':{m=line.match(/^if\s+(\S+):\s*(.+)$/);st.hints.push(m?{c:m[1],t:m[2]}:{t:line});break}
      // deduction: ID [final] if COND | sentence with {blank} words | what it means once solved
      case 'deduce':{m=line.match(/^(\w+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        // "... | why | needs A + B": the deduction also needs these two proofs attached (evidence or statement ids; A/B2 = either)
        if(m){let why=m[5],needs=null;const k=why.match(/^(.*?)\s*\|\s*needs\s+(.+)$/);if(k){why=k[1];needs=k[2].split('+').map(x=>x.trim().split('/').map(y=>y.trim()))}
        st.cases.push({id:m[1],final:!!m[2],c:m[3],text:m[4],why,needs,blanks:[...m[4].matchAll(/\{([^}|]+)(?:\|([^}]+))?\}/g)].map(x=>x[2]||x[1])})}break}
      // evidence: id | label | picture | what it is | Korean written on it (optional)
      case 'evidence':{const [id,label,icon,desc,kor]=line.split('|').map(x=>(x||'').trim());st.evidence[id]={id,label,icon,desc,ko:kor};break}
      case 'case':{m=line.match(/^(\w+)\s+(\S+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        if(m)st.cases.push({id:m[1],a:m[2],final:!!m[3],c:m[4],q:m[5],why:m[6]});break}
      // examine: art KEY / prompt TEXT / detail ID X% Y% R [key] | what you notice ! effects
      case 'examine':{
        if(m=line.match(/^(art|prompt)\s+(.+)$/))cur[m[1]]=m[2];
        else if(m=line.match(/^detail\s+(\w+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(\s+key)?\s*\|\s*(.+?)(?:\s+!\s+(.+))?$/))
          cur.details.push({id:m[1],x:+m[2],y:+m[3],r:+m[4],key:!!m[5],t:m[6],fx:m[7]?fx(m[7]):[]});
        break}
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
        // "them@FLAG ..." = this message only arrives once FLAG is set
        else if(m=line.match(/^day(?:@(\S+))?\s+(.+)/))cur.m.push({d:m[2],c:m[1]});
        else if(m=line.match(/^(them|me)(?:@(\S+))?\s+(\S+)\s+(.+)/))cur.m.push({me:m[1]==='me',c:m[2],t:m[3],ko:m[4]});
        else if(m=line.match(/^sys(?:@(\S+))?\s+(.+)/))cur.m.push({sys:1,c:m[1],ko:m[2]});
        // "voice@FLAG 13:20 who 한국어" = a voicemail: sound only
        else if(m=line.match(/^voice(?:@(\S+))?\s+(\S+)\s+([a-z_]+)\s+(.+)/))cur.m.push({vm:1,c:m[1],t:m[2],who:m[3],ko:m[4]});
        else if(m=line.match(/^note(?:@(\S+))?\s+(.+)/)){cur.note=m[2];cur.noteC=m[1]}
        break}
      case 'scene':{
        if(line.startsWith('~'))node({who:'narr',en:line.slice(1).trim()});
        else if(m=line.match(/^\((.*)\)$/)){if(last)last.en=m[1]}
        else if(line.startsWith('!')){if(last){const f=fx(line.slice(1));last.fx=(last.fx||[]).concat(f);
          f.filter(e=>e.k==='statement').forEach(e=>st.statements[e.a]={id:e.a,node:last.id})}}
        // "* label -> TARGET [if COND] [! effects]": the choice only shows when COND holds
        else if(m=line.match(/^\*\s+(.+?)\s+->\s+(.+?)(?:\s+if\s+(\S+))?(?:\s+!\s+(.+))?$/)){
          const lab=m[1],o={go:m[2],c:m[3],fx:m[4]?fx(m[4]):[]};
          if(lab.startsWith('['))o.en=lab.replace(/^\[|\]$/g,'');else{o.ko=lab;o.lang=st.meta.lang||'ko'}(last.ch=last.ch||[]).push(o)}
        else if(m=line.match(/^->\s*(.+)$/)){if(last)last.next=m[1].trim()}
        else if(m=line.match(/^<-\s*(.+)$/)){if(last)last.rewind=m[1].trim()}
        else if(m=line.match(/^@build\s+(.+)$/))node({type:'build',en:m[1],tiles:[],ans:[]});
        else if(m=line.match(/^tiles:\s*(.+)$/))last.tiles=m[1].split('|').map(s=>s.trim());
        else if(m=line.match(/^@type\s+(.+)$/))node({type:'type',en:m[1],ans:[]});
        // "@number prompt | time|won|phone|count": a number pad; answers are compared digit by digit
        else if(m=line.match(/^@number\s+(.+?)(?:\s*\|\s*(time|won|phone|count))?$/))node({type:'number',en:m[1],kind:m[2]||'count',ans:[]});
        else if(m=line.match(/^answer:\s*(.+?)\s+->\s+(.+)$/))last.ans.push([last.type==='type'||last.type==='number'?m[1].trim():m[1].split('|').map(s=>s.trim()),m[2].trim()]);
        else if(m=line.match(/^miss\s+->\s+(.+)$/))last.miss=m[1].trim();
        else if(m=line.match(/^@camera\s+(?:([\d.]+)\s+([\d.]+)\s*\|\s*)?(.+)$/))node({type:'camera',tx:+(m[1]||50),ty:+(m[2]||50),en:m[3]});
        else if(m=line.match(/^@photo\s+(.+)$/))node({type:'photo',en:m[1]});
        else if(m=line.match(/^@present\s+(.+)$/))node({type:'present',en:m[1],shows:[]});
        else if(m=line.match(/^show:\s*(\S+)\s+->\s+(.+)$/))last.shows.push([m[1],m[2].trim()]);
        // "@contradict prompt" then "pair: A + B -> TARGET" (A/B = statement or evidence ids, either order)
        else if(m=line.match(/^@examine\s+(\w+)$/))node({type:'examine',exam:m[1]});
        else if(m=line.match(/^@contradict\s+(.+)$/))node({type:'contradict',en:m[1],pairs:[]});
        else if(m=line.match(/^pair:\s*(\S+)\s*\+\s*(\S+)\s+->\s+(.+)$/))last.pairs.push([[m[1],m[2]],m[3].trim()]);
        else if(m=line.match(/^@card\s+(.+?)(?:\s*\|\s*(.+))?$/))node({type:'card',title:m[1],sub:m[2]||''});
        // "who[audio]: ..." = you only hear it: no text until you've acted on it ("who[sad audio]" works too)
        else if(m=line.match(/^([a-z_]+)(?:\[([\w ]+)\])?(?:@([a-z]{2}))?:\s*(.+)$/)){const tags=(m[2]||'').split(/\s+/).filter(Boolean);
          node({who:m[1],ex:tags.find(t=>t!=='audio')||'neutral',audio:tags.includes('audio'),ko:nl(m[4]),lang:m[3]||st.meta.lang||'ko'})}
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
// Save format version. When the format changes: bump SAVE_V and add a step to MIGRATE that upgrades the old shape.
const SAVE_V=4;
const fresh=()=>({v:SAVE_V,m:{},tl:{},mx:{},ch:null,prog:{},done:{},known:{},loc:null,node:null,F:{},w:{},cs:{},nb:{},log:[],set:{auto:1,slow:0,glow:1,sound:1,size:1,dev:0},visited:{}});
const CH_FIELDS=['loc','node','F','cs','visited'];
// erasing progress keeps what you wrote about each word (for playtesting)
function freshKeepNotes(){const old=S;const n=fresh();n.set=old.set;
  Object.entries(old.w||{}).forEach(([id,r])=>{if(r&&r.note&&r.note.trim())n.w[id]={ctx:[],note:r.note,sure:r.sure||0,n:1}});n.m=old.m||{};n.tl=old.tl||{};n.mx=old.mx||{};return n}
let S=fresh();
// MIGRATE[n] turns a version-n save into version n+1. They run in order, so any old save upgrades step by step.
const MIGRATE={
  1:s=>{ // saves from before chapters existed: they were all prologue
    s.ch=WORLD.chapters[0].id;if(s.F&&s.F.solved_q5)(s.done=s.done||{})[s.ch]=1;
    s.known=s.known||{};Object.keys(s.visited||{}).forEach(p=>s.known[p]=1);if(s.loc)s.known[s.loc]=1;return s},
  2:s=>{ // word mastery starts from what the notebook already knows: how often each word was met
    s.m={};Object.entries(s.w||{}).forEach(([id,r])=>{if(r)s.m[id]={s:r.n||0,u:0,x:0,t:0}});return s},
  3:s=>{ // Chapter 1 was rewritten: its scenes changed, so progress restarts (notebook, mastery and map stay)
    s.prog={};s.done={};s.ch=WORLD.chapters[0].id;s.F={};s.cs={};s.visited={};s.node=null;s.loc=null;s.log=[];return s},
};
function migrate(s){let v=s.v||(s.ch?2:1);while(v<SAVE_V&&MIGRATE[v]){s=MIGRATE[v](s);v++}s.v=Math.max(v,s.v||0);return s}
function load(){try{const r=localStorage.getItem(KEY);if(r){S=Object.assign(fresh(),migrate(JSON.parse(r)));S.set=Object.assign(fresh().set,S.set);return true}}catch(e){console.warn('save not loaded',e)}return false}
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
// Hangul -> jamo, so 봣어요 vs 봤어요 counts as one small slip, not a whole wrong syllable
function jamo(s){const out=[];for(const ch of String(s)){const c=ch.charCodeAt(0)-0xAC00;
  if(c>=0&&c<11172){out.push('L'+Math.floor(c/588),'V'+Math.floor(c%588/28));if(c%28)out.push('T'+c%28)}else out.push(ch)}return out}
function lev(a,b){const d=Array.from({length:a.length+1},(_, i)=>[i]);for(let j=1;j<=b.length;j++)d[0][j]=j;
  for(let i=1;i<=a.length;i++)for(let j=1;j<=b.length;j++)d[i][j]=Math.min(d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+(a[i-1]===b[j-1]?0:1));return d[a.length][b.length]}
const jamoDist=(a,b)=>lev(jamo(a),jamo(b));
function wrec(id){return S.w[id]||(S.w[id]={ctx:[],note:''})}
/* ---------- word mastery (quiet: nothing shows it yet; later phases read it) ----------
   S.m[word] = {s: times seen in a line, u: times you used it right, x: times you used it wrong, t: day last seen} */
const today=()=>Math.floor(Date.now()/864e5);
const mast=id=>S.m[id]||(S.m[id]={s:0,u:0,x:0,t:0});
function noteSeen(str){idsIn(str).forEach(id=>{if(!W[id])return;const m=mast(id);m.s++;m.t=today()})}
function noteUsed(str,ok){idsIn(str).forEach(id=>{if(!W[id])return;const m=mast(id);ok?m.u++:m.x++;m.t=today()})}
// does this answer play out and then rewind you (a wrong answer)?
function leadsToRewind(t){let id=t,n=0;while(id&&n++<40){const nd=ST.nodes[tgt(id)];if(!nd)return false;if(nd.rewind)return true;
  if(nd.ch||nd.ans||nd.shows||nd.type)return false;id=nd.next}return false}
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
  const u=new SpeechSynthesisUtterance(t);u.lang='ko-KR';if(VOICE)u.voice=VOICE; // other languages: pick by line lang once they exist
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
  else if(e.k==='mixup'){const [r,h]=a.split('/').map(x=>x.trim());const k=r+'/'+h;
    if(!replay){S.mx[k]=(S.mx[k]||0)+1;noteUsed('{'+r+'}',false);toast(`Mix-up saved to your notebook: <b>${esc(r)}</b> / <b>${esc(h)}</b>`,4000)}}
  else if(e.k==='statement'){if(!S.F['st_'+a]){S.F['st_'+a]=1;if(!replay)toast('Statement saved to your case board.',2600)}}
  else if(e.k==='have')a.split(',').forEach(x=>S.F['ev_'+x.trim()]=1); // evidence you already carry, no announcement
  else if(e.k==='give')a.split(',').forEach(x=>{x=x.trim();if(!S.F['ev_'+x]){S.F['ev_'+x]=1;const ev=ST.evidence[x];if(ev&&!replay)toast(`${iconSVG(ev.icon)} Evidence: <b>${ko(ev.label,false,false)}</b>`,3500)}});
})}
function logLine(e){S.log.push(e);if(S.log.length>80)S.log.shift()}
// lines you only heard get written down once you've acted on them (any decision or move)
function revealHeard(){S.log.forEach(e=>{if(e.heard){e.heard=0;if(e.ko)ko(e.ko)}})}
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
  S.node=id;bseq=[];TFB=null;tHint=0;CSEL=[];NUMV='';EXMISS=0;runFx(nd.fx,replay);checkPattern();
  if(nd.ko&&!replay)noteSeen(nd.ko);
  if(nd.audio)HEARD[id]=(HEARD[id]||0)+1;
  if(nd.type==='camera')cam={x:22+Math.random()*10,y:24+Math.random()*10};
  if(nd.ko||(nd.who==='narr'&&nd.en))logLine({who:nd.who,ex:nd.ex,ko:nd.ko,en:nd.en,heard:nd.audio?1:0});
  save();render();
  if((S.set.auto||nd.audio)&&nd.ko&&!quiet)speak(nd.ko,nd.who);
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
  const nd=ST.nodes[p.id];if((S.set.auto||nd&&nd.audio)&&nd&&nd.ko)speak(nd.ko,nd.who);
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
  if(busy)return;sfx('tap');setBusy(true);revealHeard();runFx(c.fx);
  if(c.ko){ko(c.ko);noteUsed(c.ko,!leadsToRewind(c.go));logLine({who:'you',ko:c.ko});await speak(c.ko,'you');await new Promise(r=>setTimeout(r,250))}
  setBusy(false);go(c.go);
}
async function say(nd){
  if(busy)return;sfx('tap');setBusy(true);revealHeard();
  const words=bseq.map(i=>nd.tiles[i]);const line=words.join(' ');ko(line);logLine({who:'you',ko:line});
  const hit=nd.ans.find(a=>a[0].length===words.length&&a[0].every((w,i)=>w===words[i]));
  noteUsed(line,!!hit&&!leadsToRewind(hit[1]));
  await speakBuilt(words,line);await new Promise(r=>setTimeout(r,250));
  setBusy(false);go(hit?hit[1]:nd.miss);
}
/* ---------- typed answers: close enough counts, and you see what to fix ---------- */
let TFB=null,tHint=0;
const typedNorm=s=>plain(s).replace(/[\s.?!~,·…]/g,'');
// hint levels: 1 = first syllable of each word, 2 = first two, 3 = everything
function skeleton(nd,level){const a=plain(nd.ans[0][0]);if(level>=3)return a;
  return a.split(' ').map(w=>{const ch=[...w];return ch.map((c,i)=>i<level||/[.?!~,…]/.test(c)?c:'_').join('')}).join(' ')}
function diffHTML(user,correct){
  const u=[...user].filter(c=>!/[\s.?!~,·…]/.test(c));const cp=[...correct];const ci=cp.map((c,i)=>i).filter(i=>!/[\s.?!~,·…]/.test(cp[i]));const cc=ci.map(i=>cp[i]);
  const L=Array.from({length:u.length+1},()=>Array(cc.length+1).fill(0));
  for(let i=u.length-1;i>=0;i--)for(let j=cc.length-1;j>=0;j--)L[i][j]=u[i]===cc[j]?L[i+1][j+1]+1:Math.max(L[i+1][j],L[i][j+1]);
  const okU=new Set(),okC=new Set();let i=0,j=0;
  while(i<u.length&&j<cc.length){if(u[i]===cc[j]){okU.add(i);okC.add(j);i++;j++}else if(L[i+1][j]>=L[i][j+1])i++;else j++}
  const yours=u.map((c,k)=>okU.has(k)?esc(c):`<mark class="bad">${esc(c)}</mark>`).join('');
  const fixed=cp.map((c,k)=>{const n=ci.indexOf(k);return n<0||okC.has(n)?esc(c):`<mark class="fix">${esc(c)}</mark>`}).join('');
  return `<div class="tfb"><div class="label">Close enough! Watch the highlighted parts.</div><div class="tfrow"><span>You wrote</span><b>${yours}</b></div><div class="tfrow"><span>Correct</span><b>${fixed}</b></div></div>`;
}
async function sayTyped(nd,val){
  if(busy)return;const v=typedNorm(val);if(!v){toast('Type something first.');return}revealHeard();
  sfx('tap');
  const scored=nd.ans.map(a=>({a,d:jamoDist(v,typedNorm(a[0])),n:jamo(typedNorm(a[0])).length})).sort((x,y)=>x.d-y.d);
  const best=scored[0],lim=best?Math.max(1,Math.floor(best.n*.15)):0;
  if(best&&best.d<=lim)noteUsed(best.a[0],!leadsToRewind(best.a[1]));
  if(best&&best.d===0){ko(best.a[0]);logLine({who:'you',ko:best.a[0]});setBusy(true);await speak(best.a[0],'you');await new Promise(r=>setTimeout(r,250));setBusy(false);go(best.a[1]);return}
  if(best&&best.d<=lim){ko(best.a[0]);logLine({who:'you',ko:best.a[0]});TFB={html:diffHTML(val,plain(best.a[0])),target:best.a[1]};render();speak(best.a[0],'you');return}
  logLine({who:'you',ko:val});go(nd.miss);
}
function spot(i){const x=ST.places[S.loc].spots[i];if(!x)return;sfx('tap');revealHeard();
  if(x.kind==='->')go(x.t);else if(x.t==='phone')openPhone();else{const m=x.t.match(/^place\s+(\S+)/);if(m)enter(m[1])}}
// playtest: jump ahead to the next decision without the voices
function skipAhead(){
  quiet=true;stopAudio();let n=0;
  while(S.node&&n++<60){const nd=ST.nodes[S.node];
    if(nd.ch||['build','type','present','camera','contradict','number','examine'].includes(nd.type))break;
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
  const exam=nd&&nd.type==='examine'?ST.examines[nd.exam]:null;   // a close-up takes over the picture window
  const artName=exam?exam.art:l.art;
  const ak=artName+(artName==='bus'?'|'+(S.F.led||''):'');
  if(ak!==artKey){const w=$('#art');w.innerHTML=(ART[artName]||ART.madang)();w.classList.remove('in');void w.offsetWidth;w.classList.add('in');artKey=ak}
  const amb=exam?'none':l.ambient||'none';if(amb!==ambKey){$('#amb').innerHTML=ambientHTML(amb);ambKey=amb}
  let h='';
  if(nd&&nd.type==='camera')h+=`<div class="vf" id="vf" style="left:${cam.x}%;top:${cam.y}%"><span>Drag me</span></div>`;
  if(exam){const got=d=>S.F['ex_'+exam.id+'_'+d.id];
    h+=`<div class="exlayer" id="exam">${exam.details.map(d=>got(d)?`<span class="exmark" style="left:${d.x}%;top:${d.y}%"></span>`:EXMISS>=4?`<span class="exhint" style="left:${d.x}%;top:${d.y}%"></span>`:'').join('')}</div>`}
  if(nd&&nd.type==='card')h+=`<div class="card-title"><b>${esc(nd.title)}</b>${nd.sub?`<span>${esc(nd.sub)}</span>`:''}</div>`;
  if(!nd)l.spots.forEach((x,i)=>{if(!cond(x.c))return;h+=`<button class="hs" data-hs="${i}" style="left:${x.x}%;top:${x.y}%" aria-label="${esc(x.l)}"><i></i><span>${esc(x.l)}</span></button>`});
  if(nd&&nd.ko&&!nd.audio&&glowFor!==S.node){glowFor=S.node;h+=glowHTML(idsIn(nd.ko))}
  if(S.loc!==lastLoc&&!(nd&&nd.type==='card'))h+=`<div class="placecard"><b>${esc(l.name||'')}</b><span>${esc(l.sub||'')}</span></div>`;
  lastLoc=S.loc;
  h+=`<div class="flash" id="flash"></div>`;
  $('#fx').innerHTML=h;
  $('#fx').querySelectorAll('.hs').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  if(nd&&nd.type==='camera')dragFrame($('#vf'));
  const sb=$('#sb'),sf=$('#sf');let body='',foot='';
  const devSkip=S.set.dev&&nd&&!nd.ch&&!['build','type','present','contradict','number','examine'].includes(nd.type)?`<button class="btn dev" id="bSkip">⏭ Skip to next decision</button>`:'';
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
  }else if(nd.type==='type'){
    if(TFB){body=`<div class="en">${esc(nd.en)}</div>${TFB.html}`;foot=cont('Continue')}
    else{
      body=`<div class="en">${esc(nd.en)}</div><form class="typeans big" id="tf"><input id="tin" lang="ko" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="send" placeholder="Type it in Korean"></form>
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
      <div class="numpad">${keys.map(k=>`<button class="nk ${k==='✓'?'ok':''}" data-nk="${k}" ${k==='✓'&&!NUMV?'disabled':''}>${k==='✓'?'Say it':k}</button>`).join('')}</div>`;
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
        ${nd.en?`<div class="en">${esc(nd.en)}</div>`:''}`;
    }
    if(nd.ch)foot=`<div class="acts">${nd.ch.map((x,i)=>!cond(x.c)?'':`<button class="btn ${x.ko?'ko':'act'}" data-ch="${i}">${x.ko?`<span class="qm">“</span><span>${ko(x.ko,false,false)}<span class="qm">”</span></span>`:esc(x.en)}</button>`).join('')}</div>${backBtn?`<div class="controw">${backBtn}</div>`:''}`;
    else foot=`${cont(nd.next||nd.rewind?'Continue':'Look around')}${devSkip}`;
  }
  sb.innerHTML=body;sf.innerHTML=foot;sb.scrollTop=0;setBusy(busy);
  if(nd&&revealFor!==S.node){revealFor=S.node;const k=sb.querySelector('.koline,.narr');const ms=reveal(k);revealUntil=Date.now()+ms;
    const en=sb.querySelector('.en');if(en){en.classList.add('rv');en.style.animationDelay=Math.min(ms,1400)+'ms'}}
  document.querySelectorAll('#sb [data-hs],#sf [data-hs]').forEach(b=>b.onclick=()=>spot(+b.dataset.hs));
  sf.querySelectorAll('[data-ch]').forEach(b=>b.onclick=()=>choose(nd.ch[+b.dataset.ch]));
  const bn=$('#bNext');if(bn)bn.onclick=TFB?()=>{const t=TFB.target;TFB=null;go(t)}:next;
  if($('#bSayT')){const tin=$('#tin');$('#bSayT').onclick=()=>sayTyped(nd,tin.value);$('#tf').onsubmit=e=>{e.preventDefault();sayTyped(nd,tin.value)};
    $('#bHintT').onclick=()=>{tHint=Math.min(tHint+1,3);const v=tin.value;render();const t2=$('#tin');t2.value=v;t2.focus()}}
  if($('#bSkip'))$('#bSkip').onclick=skipAhead;
  if($('#bMap'))$('#bMap').onclick=openMap;
  sb.querySelectorAll('[data-show]').forEach(b=>b.onclick=()=>present(nd,b.dataset.show));
  sb.querySelectorAll('[data-cx]').forEach(b=>b.onclick=()=>{const k=b.dataset.cx;sfx('tap');
    if(CSEL.includes(k))CSEL=CSEL.filter(x=>x!==k);else{CSEL.push(k);if(CSEL.length>2)CSEL.shift()}
    const top=sb.scrollTop;render();sb.scrollTop=top});
  if($('#bClash'))$('#bClash').onclick=()=>clash(nd);
  const ex=$('#exam');if(ex)ex.onclick=e=>{const r=ex.getBoundingClientRect();examTap(nd,(e.clientX-r.left)/r.width*100,(e.clientY-r.top)/r.height*100)};
  sb.querySelectorAll('[data-nk]').forEach(b=>b.onclick=()=>{const k=b.dataset.nk;sfx('tap');
    if(k==='✓'){sayNumber(nd);return}if(k==='⌫')NUMV=NUMV.slice(0,-1);else if(NUMV.length<11)NUMV+=k;render()});
  if($('#bBack'))$('#bBack').onclick=goBack;
  const bs=sb.querySelector('[data-say]');if(bs)bs.onclick=()=>{sfx('tap');speak(nd.ko,nd.who)};
  sb.querySelectorAll('[data-t]').forEach(b=>b.onclick=()=>{sfx('tap');bseq.push(+b.dataset.t);speak(nd.tiles[+b.dataset.t],'you');render()});
  if($('#bClr'))$('#bClr').onclick=()=>{bseq=[];render()};
  if($('#bLeave'))$('#bLeave').onclick=()=>{S.node=null;BACK=[];save();render()};
  if($('#bSay'))$('#bSay').onclick=()=>say(nd);
  if($('#bShut'))$('#bShut').onclick=()=>shoot(nd);
  dots();save();
}
// a line you only hear: a listen button, and pictures for the words you've already looked up (no text)
const HEARD={}; // how many times each sound-only line has played this session
/* ---------- examining an object: tap the details you notice ---------- */
let EXMISS=0;
function examTap(nd,px,py){
  const x=ST.examines[nd.exam];const ex=$('#exam');const ratio=ex?ex.clientHeight/ex.clientWidth:.75;
  const d=x.details.find(d=>!S.F['ex_'+x.id+'_'+d.id]&&Math.hypot(px-d.x,(py-d.y)*ratio)<=d.r)
    ||x.details.find(d=>Math.hypot(px-d.x,(py-d.y)*ratio)<=d.r);
  if(!d){EXMISS++;sfx('tap');if(ex){const p=document.createElement('span');p.className='exripple';p.style.left=px+'%';p.style.top=py+'%';ex.appendChild(p);setTimeout(()=>p.remove(),600)}
    if(EXMISS===4)render();return}
  if(S.F['ex_'+x.id+'_'+d.id])return;
  S.F['ex_'+x.id+'_'+d.id]=1;sfx('learn');buzz(20);runFx(d.fx);logLine({who:'narr',en:plain(d.t)});noteSeen(d.t);
  const top=$('#sb').scrollTop;render();$('#sb').scrollTop=top;
}

/* ---------- number answers ---------- */
let NUMV='';
const digits=s=>String(s).replace(/\D/g,'');
function fmtNum(v,kind){
  if(kind==='time'){const d=v.slice(0,4);return d.length<=2?d:d.slice(0,d.length-2)+':'+d.slice(-2)}
  if(kind==='won')return (+v).toLocaleString('en-US')+' 원';
  if(kind==='phone'){const d=v;return d.length<=3?d:d.length<=7?d.slice(0,3)+'-'+d.slice(3):d.slice(0,3)+'-'+d.slice(3,7)+'-'+d.slice(7)}
  return v}
async function sayNumber(nd){
  if(busy||!NUMV)return;revealHeard();
  const said=fmtNum(NUMV,nd.kind);logLine({who:'you',ko:said});
  const hit=nd.ans.find(a=>digits(a[0])===NUMV.replace(/^0+(?=\d)/,nd.kind==='phone'?'0':''));
  go(hit?hit[1]:nd.miss);
}
function heardHTML(nd){
  const pics=(HEARD[nd.id]||0)<2?'':idsIn(nd.ko).filter((id,i,a)=>a.indexOf(id)===i&&W[id]&&!W[id].g&&S.nb[id]).map(id=>iconSVG(W[id].p,'hicon')).join('');
  return `<div class="heardbox"><button class="listen" data-say aria-label="Listen again">🔊 Listen again</button>${pics?`<div class="heardpics">${pics}</div>`:''}<div class="heardnote">${pics?'Pictures for the words you know.':'You only heard this. It gets written down once you act on it.'}</div></div>`}
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
    const tabs=[['all','All'],['todo','No note'],['guess','Guesses'],['sure','Sure'],['gram','Grammar'],['pat','Patterns'],['num','Numbers'],['mix','Mix-ups'],['sym','Symbols']];
    let inner=`<div class="tabs">${tabs.map(([k,t])=>`<button class="tab ${nbTab===k?'on':''}" data-tab="${k}">${t}</button>`).join('')}</div>`;
    if(['all','todo','guess','sure'].includes(nbTab))inner+=`<div class="label">${by('sure').length} sure · ${by('guess').length} guesses · ${vocab.length} seen</div>`;
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
    if(e.heard)return`<div class="hl"><div style="min-width:0;flex:1"><div class="hn">${esc(c.n||'')}</div><div class="hk heardrow">🔊 Heard, not written down yet</div></div><button class="say" data-hi="${i}" aria-label="Hear it">▶</button></div>`;
    const face=you?'':c.look?portrait(c.look,e.ex):e.who==='sign'?'':speakerGlyph();
    return`<div class="hl ${you?'you':''}">${face?`<div class="pt sm" style="--cbg:${c.c||'#888'}">${face}</div>`:''}<div style="min-width:0;flex:1">
      <div class="hn">${esc(you?'You':e.who==='sign'?'Written':c.n||'')}</div><div class="hk">${ko(e.ko,true,false)}</div>${e.en?`<div class="en">${esc(e.en)}</div>`:''}</div>
      <button class="say" data-hi="${i}" aria-label="Hear it">▶</button></div>`}).join('');
  o.querySelector('#hb').innerHTML=rows||'<div class="empty">Nothing yet.</div>';
  o.querySelectorAll('[data-hi]').forEach(b=>b.onclick=()=>{const e=S.log[+b.dataset.hi];speak(e.ko,e.who)});
  const hb=o.querySelector('#hb');hb.scrollTop=hb.scrollHeight;
}

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
let CSEL=[];
// a contradiction beat: the two things you picked either clash (one of the pairs) or they don't
async function clash(nd){
  if(busy||CSEL.length!==2)return;sfx('tap');revealHeard();
  const hit=nd.pairs.find(p=>p[0].every(k=>CSEL.includes(k)));
  const name=k=>ST.statements[k]?plain(ST.nodes[ST.statements[k].node].ko):plain((ST.evidence[k]||{}).label||k);
  logLine({who:'narr',en:`You point out: ${name(CSEL[0])} / ${name(CSEL[1])}.`});
  if(hit)CSEL.filter(k=>ST.statements[k]).forEach(k=>noteUsed(ST.nodes[ST.statements[k].node].ko,true));
  go(hit?hit[1]:nd.miss);
}
// about 14 words to choose from: every blank on this chapter's board, plus a few others you've met. Typing searches everything.
function shortlist(q,filter){
  const ok=id=>W[id]&&!W[id].g&&S.w[id];
  if(filter)return Object.keys(S.w).filter(id=>ok(id)&&(id.includes(filter)||(S.w[id].note||'').toLowerCase().includes(filter.toLowerCase()))).slice(0,16);
  let h=7;for(const ch of q.id)h=(h*31+ch.charCodeAt(0))>>>0;
  const rnd=()=>{h=(h*1103515245+12345)>>>0;return h/4294967296};
  const mix=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(rnd()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
  const pool=new Set();ST.cases.forEach(c=>c.blanks.forEach(a=>{if(W[a])pool.add(a)}));
  if(q.blanks.some(b=>W[b]&&W[b].g))Object.keys(WORLD.tells).concat(['이에요','아니에요']).filter(id=>W[id]).forEach(id=>pool.add(id));
  mix(Object.keys(S.w).filter(id=>ok(id)&&W[id].p&&!pool.has(id))).slice(0,Math.max(0,16-pool.size)).forEach(x=>pool.add(x));
  return mix([...pool]);
}
// sentence with slots; filled = array of words (or null)
function dedHTML(q,mode){
  let k=0;return esc(q.text).replace(TOK,(m,surf,id)=>{const i=k++;
    if(mode==='solved')return `<b class="slot done">${esc(surf)}</b>`;
    if(mode==='closed')return `<span class="slot empty">＿＿</span>`;
    const f=(FILL[q.id]||[])[i];return `<button class="slot ${f?'filled':'empty'} ${i===ACT?'active':''}" data-slot="${i}">${f?esc(f):'＿＿'}</button>`});
}
function caseBoard(tab){
  if(typeof tab==='string')boardTab=tab; // the top-bar button passes a click event, not a tab name
  const o=overlay(`<div class="panel">${head('사건')}<div class="ph-body" id="cbb"></div></div>`);
  o.querySelector('.x').onclick=()=>close(o);
  let filter='',miss=false;
  const check=q=>{
    const f=FILL[q.id]||[];
    if(q.blanks.some((b,i)=>!f[i])){toast('Fill in every blank first.');return}
    const pf=PROOF[q.id]||[];if(q.needs&&q.needs.some((x,i)=>!pf[i])){toast('Attach your proof first.');return}
    if(q.blanks.every((b,i)=>b.split('/').some(a=>normAns(a)===normAns(f[i])))&&proofOk(q,pf)){
      S.cs[q.id]=1;S.F['solved_'+q.id]=1;PMODE=null;q.blanks.forEach(b=>noteUsed('{'+b+'}',true));
      q.blanks.filter(b=>WORLD.tells[b]&&!S.tl[b]).forEach(b=>{S.tl[b]=1;setTimeout(()=>toast(`New tell in your notebook: <b>${esc(b)}</b>`,4000),400)});save();pickQ=null;filter='';miss=false;sfx('solve');buzz([20,40,20]);draw();
      if(q.final)setTimeout(()=>{close(o);finale()},900);else if(caseReadyNow())toast('Everything you know fits together.');
    }else{sfx('wrong');buzz(60);miss=true;draw()}
  };
  const place=(q,word)=>{const f=FILL[q.id]=FILL[q.id]||[];f[ACT]=word;miss=false;sfx('tap');
    const nxt=q.blanks.findIndex((b,i)=>!f[i]);if(nxt>=0)ACT=nxt;filter='';draw()};
  const draw=()=>{
    const tabs=`<div class="tabs"><button class="tab ${boardTab==='ded'?'on':''}" data-bt="ded">Deductions</button><button class="tab ${boardTab==='ev'?'on':''}" data-bt="ev">Evidence · ${owned().length}</button><button class="tab ${boardTab==='st'?'on':''}" data-bt="st">Statements · ${ownedSt().length}</button></div>`;
    let h=tabs;
    if(boardTab==='st'){
      const sts=ownedSt();
      h+=sts.length?`<div class="evlist">${sts.map(x=>stCard(x,`class="evcard stcard" data-sth="${x.id}"`)).join('')}</div>`:`<div class="empty">Nothing yet. When someone says something that matters, it's saved here.</div>`;
    }else if(boardTab==='ev'){
      const ev=owned();
      h+=ev.length?`<div class="evlist">${ev.map(e=>`<button class="evcard" data-ev="${e.id}">${iconSVG(e.icon)}<span><b>${ko(e.label,false,false)}</b><small>${esc(e.desc)}</small></span></button>`).join('')}</div>`:`<div class="empty">Nothing yet. Things you find that matter will collect here.</div>`;
    }else{
      const qs=ST.cases.filter(q=>cond(q.c));
      h+=qs.length?'<div class="empty">Fill each blank with a word, and attach proof where it asks. When everything is right, the deduction locks in. If something is wrong, you won\'t be told what.</div>':'<div class="empty">Nothing to work out yet. Look around and see what you can find.</div>';
      h+=qs.map(q=>{
        if(S.cs[q.id])return`<div class="q solved"><div class="ded">${dedHTML(q,'solved')}</div>${q.needs?`<div class="proofrow done">${(PROOF[q.id]||[]).filter(Boolean).map(id=>`<span class="pslot filled">${proofChip(id)}</span>`).join('')}</div>`:''}<div class="why">${esc(q.why)}</div></div>`;
        if(pickQ!==q.id)return`<div class="q"><div class="ded">${dedHTML(q,'closed')}</div>${q.needs?`<div class="why">Needs ${q.needs.length} pieces of proof.</div>`:''}<button class="btn-ink" data-open="${q.id}">Work it out</button></div>`;
        const pf=PROOF[q.id]||[];
        const proofRow=q.needs?`<div class="proofrow"><span class="plabel">Proof</span>${q.needs.map((x,i)=>`<button class="pslot ${pf[i]?'filled':''} ${PMODE===i?'active':''}" data-ps="${i}">${pf[i]?proofChip(pf[i]):'＋ Attach'}</button>`).join('')}</div>`:'';
        if(PMODE!==null&&q.needs)return`<div class="q open"><div class="ded">${dedHTML(q,'open')}</div>${proofRow}
          <div class="label">Pick the proof</div><div class="pick proofpick">${owned().map(e=>`<button class="pp" data-pp="${e.id}">${proofChip(e.id)}</button>`).join('')}${ownedSt().map(x=>`<button class="pp" data-pp="${x.id}">${proofChip(x.id)}</button>`).join('')}</div>
          <div class="row"><button class="btn-ink" data-pcancel>Back to words</button></div></div>`;
        return`<div class="q open"><div class="ded">${dedHTML(q,'open')}</div>${proofRow}
          <form class="typeans" id="ta"><input id="ti" lang="ko" autocomplete="off" placeholder="Type a word, or pick one below" value="${esc(filter)}"><button class="btn-ink" type="submit">Put in</button></form>
          <div class="pick">${shortlist(q,filter).map(id=>`<button class="w ${status(id)}" data-pk="${esc(id)}" data-w="">${esc(id)}</button>`).join('')||'<span class="empty">No matching words.</span>'}</div>
          ${miss?`<div class="miss">Something doesn't follow.</div>`:''}
          <div class="row"><button class="btn-ink" data-clear="${q.id}">Clear</button><button class="btn-ink primary" data-check="${q.id}">Check</button></div></div>`;
      }).join('');
    }
    o.querySelector('#cbb').innerHTML=h;
    o.querySelectorAll('[data-bt]').forEach(b=>b.onclick=()=>{boardTab=b.dataset.bt;sfx('tap');draw()});
    o.querySelectorAll('[data-ev]').forEach(b=>b.onclick=()=>evidenceSheet(b.dataset.ev));
    o.querySelectorAll('[data-sth]').forEach(b=>b.onclick=()=>{const nd=ST.nodes[ST.statements[b.dataset.sth].node];speak(nd.ko,nd.who)});
    o.querySelectorAll('[data-open]').forEach(b=>b.onclick=()=>{sfx('tap');pickQ=b.dataset.open;PMODE=null;FILL[pickQ]=FILL[pickQ]||[];ACT=Math.max(0,ST.cases.find(x=>x.id===pickQ).blanks.findIndex((x,i)=>!FILL[pickQ][i]));filter='';miss=false;draw()});
    const q=ST.cases.find(x=>x.id===pickQ);if(!q||boardTab!=='ded')return;
    o.querySelectorAll('[data-slot]').forEach(b=>b.onclick=()=>{ACT=+b.dataset.slot;PMODE=null;sfx('tap');draw()});
    o.querySelectorAll('[data-ps]').forEach(b=>b.onclick=()=>{const i=+b.dataset.ps;PMODE=PMODE===i?null:i;miss=false;sfx('tap');draw()});
    o.querySelectorAll('[data-pp]').forEach(b=>b.onclick=()=>{const pf=PROOF[q.id]=PROOF[q.id]||[];const id=b.dataset.pp;
      const other=pf.indexOf(id);if(other>=0&&other!==PMODE)pf[other]=null;pf[PMODE]=id;
      const nxt=q.needs.findIndex((x,i)=>!pf[i]);PMODE=nxt>=0?nxt:null;sfx('tap');draw()});
    const pc=o.querySelector('[data-pcancel]');if(pc)pc.onclick=()=>{PMODE=null;draw()};
    o.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>place(q,b.dataset.pk));
    o.querySelectorAll('[data-clear]').forEach(b=>b.onclick=()=>{FILL[q.id]=[];PROOF[q.id]=[];PMODE=null;ACT=0;miss=false;draw()});
    o.querySelectorAll('[data-check]').forEach(b=>b.onclick=()=>check(q));
    const ti=o.querySelector('#ti');if(ti){ti.oninput=e=>{filter=e.target.value.trim();
      const pk=o.querySelector('.pick');pk.innerHTML=shortlist(q,filter).map(id=>`<button class="w ${status(id)}" data-pk="${esc(id)}" data-w="">${esc(id)}</button>`).join('')||'<span class="empty">No matching words.</span>';
      pk.querySelectorAll('[data-pk]').forEach(b=>b.onclick=()=>place(q,b.dataset.pk))}}
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
// a "present evidence" beat: pick something you've found to show them
async function present(nd,id){
  if(busy)return;sfx('tap');revealHeard();const hit=nd.shows.find(s=>s[0]===id);
  const e=ST.evidence[id];logLine({who:'narr',en:'You show them: '+plain(e.label)+'.'});
  go(hit?hit[1]:nd.miss);
}

const msgsOf=t=>t.m.filter(m=>cond(m.c));
const msgCount=t=>msgsOf(t).filter(m=>!m.d).length;
const unread=t=>(S.F['readn_'+t.id]||0)<msgCount(t);
function openPhone(){
  const o=overlay(`<div class="phone" role="dialog" aria-label="Phone"><div class="ph-status"><span>08:47</span><span>▂▄▆ 42%</span></div><div id="phv" style="flex:1;display:flex;flex-direction:column;min-height:0"></div></div>`,'center');
  const list=()=>{
    stopAudio();
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><b>메시지</b><button id="pc">Close</button></div><div class="ph-list">${ST.phones.map(t=>`<button class="thr" data-th="${t.id}"><span class="av" style="background:${t.c}">${esc(t.av)}</span><span style="min-width:0;flex:1"><div class="nm">${esc(t.name)}</div><div class="pv">${(()=>{const m=msgsOf(t).filter(m=>m.ko).pop()||{};return m.vm?'🔊 음성 메시지':esc(plain(m.ko||''))})()}</div></span>${unread(t)?'<span class="new"></span>':''}</button>`).join('')}</div>`;
    o.querySelector('#pc').onclick=()=>close(o);
    o.querySelectorAll('[data-th]').forEach(b=>b.onclick=()=>{sfx('tap');thread(ST.phones.find(t=>t.id===b.dataset.th))});
  };
  const thread=t=>{
    const before=S.F['readn_'+t.id]||0;msgsOf(t).filter(m=>!m.d).slice(before).forEach(m=>noteSeen(m.ko));
    runFx(t.fx);S.F['read_'+t.id]=1;S.F['readn_'+t.id]=msgCount(t);const ms=msgsOf(t);
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><button id="pb">‹ Back</button><b>${esc(t.name)}</b></div><div class="msgs">${ms.map((m,i)=>m.d?`<div class="day">${ko(m.d)}</div>`:m.sys?`<div class="bub sys">${esc(m.ko)}</div>`:m.vm?`<button class="bub vm" data-vm="${i}"><span class="vmplay">▶</span> 음성 메시지<small>${m.t} · tap to listen</small></button>`:`<div class="bub ${m.me?'me':''}" data-bi="${i}">${ko(m.ko)}<small>${m.t} · tap to hear</small></div>`).join('')}${t.note&&cond(t.noteC)?`<div class="ph-note">${esc(t.note)}</div>`:''}</div>`;
    o.querySelectorAll('[data-bi]').forEach(b=>b.onclick=()=>speak(ms[+b.dataset.bi].ko,'sign'));
    o.querySelectorAll('[data-vm]').forEach(b=>b.onclick=()=>{const m=ms[+b.dataset.vm];S.F['vm_'+t.id]=1;speak(m.ko,m.who)});
    o.querySelector('#pb').onclick=list;save();dots();
    const mm=o.querySelector('.msgs');if(mm)mm.scrollTop=mm.scrollHeight;
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
      ${S.set.dev?`<div class="empty">Tracking ${Object.keys(S.m).length} words · save format ${S.v}</div><button class="btn-ink" id="cps">Copy save data</button>`:''}
      <button class="btn-ink" id="rs" style="color:#e59a87">${confirmReset?'Tap again to erase all progress':'Start over'}</button>`;
    o.querySelectorAll('[data-k]').forEach(b=>b.onclick=()=>{S.set[b.dataset.k]=+b.dataset.v;save();sfx('tap');draw();document.documentElement.dataset.size=S.set.size});
    o.querySelector('#tv').onclick=()=>speak('{안녕하세요}!','sujin');
    const cps=o.querySelector('#cps');if(cps)cps.onclick=()=>{try{navigator.clipboard.writeText(JSON.stringify(S));toast('Save data copied.')}catch(e){toast('Could not copy.')}};
    o.querySelector('#rs').onclick=()=>{if(!confirmReset){confirmReset=true;draw()}else{S=freshKeepNotes();BACK=[];save();o.remove();title()}};
  };draw();
}

/* ---------- chapters ---------- */
function useChapter(id){
  const c=CH[id]||CH[WORLD.chapters[0].id];
  ST={examines:Object.assign({},c.examines),statements:Object.assign({},c.statements),evidence:Object.assign({},WORLD.evidence,c.evidence),cast:Object.assign({},WORLD.cast,c.cast),words:W,places:c.places,nodes:c.nodes,cases:c.cases,phones:c.phones,hints:c.hints,
    patterns:WORLD.patterns.concat(c.patterns),meta:Object.assign({},WORLD.meta,c.meta),map:WORLD.map,chapters:WORLD.chapters};
}
const chIndex=id=>WORLD.chapters.findIndex(c=>c.id===id);
const chInfo=id=>WORLD.chapters.find(c=>c.id===id)||{};
const chReady=id=>!!CH[id];
const chUnlocked=id=>{const i=chIndex(id);return i===0||!!S.done[WORLD.chapters[i-1].id]};
// a chapter can be several story files in a row ("continues" in the chapter list): they play as one
const groupHead=id=>{let i=Math.max(0,chIndex(id));while(i>0&&WORLD.chapters[i].cont)i--;return WORLD.chapters[i]};
const groupParts=head=>{const i=chIndex(head.id),out=[head];for(let k=i+1;k<WORLD.chapters.length&&WORLD.chapters[k].cont;k++)out.push(WORLD.chapters[k]);return out};
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
  if(!S.ch)S.ch=WORLD.chapters[0].id;
  if(!CH[S.ch])S.ch=WORLD.chapters[0].id;
  useChapter(S.ch);
  if(!S.loc||!ST.places[S.loc])S.loc=ST.meta['start-place'];
  if(S.node&&!ST.nodes[S.node])S.node=null;
  revealFor=S.node;lastLoc=S.loc;
  $('#boot').remove();
  $('#bNote').onclick=notebook;$('#bCase').onclick=()=>caseBoard();$('#bPhone').onclick=openPhone;$('#bMenu').onclick=menu;
  $('#locKo').onclick=openMap;$('#locSub').onclick=openMap;
  render();title();
}
boot();
if('serviceWorker' in navigator&&location.protocol==='https:'&&!/claude\.ai|claudeusercontent/.test(location.host)){
  navigator.serviceWorker.register('sw.js').catch(()=>{});
}
