/* ============ FLOW ============
   Moving through the story: beats, choices, answers, rewinds, chapters. */

/* ---------- flow ---------- */
const $=s=>document.querySelector(s);
let bseq=[],busy=false,glowFor=null,revealFor=null,revealUntil=0,artKey=null,ambKey=null,lastLoc=null,quiet=false,cam={x:28,y:30};
let BACK=[];const SEEN=new Set();   // lines you can step back to in the current scene; beats already shown
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
  S.node=id;bseq=[];TFB=null;TREPLY=null;tHint=0;CSEL=[];NUMV='';EXMISS=0;runFx(nd.fx,replay);checkPattern();
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
  const cm=COMMON.find(c=>jamoDist(v,typedNorm(c[0]))<=1);
  if(cm){logLine({who:'you',ko:val});TREPLY={ko:cm[1],en:cm[2]};render();speak(cm[1],nd.to||'sign');return}
  logLine({who:'you',ko:val});go(nd.miss);
}
// small talk while you're meant to be asking something: they answer, and wait
const COMMON=[['안녕하세요','{안녕하세요}!','They say hello back, and wait for you to go on.'],['안녕','{네}, {안녕하세요}~','They nod, and wait.'],
  ['고마워요','{네}~','They smile. That wasn\'t what you came to say, though.'],['감사합니다','{네}~','They smile. That wasn\'t what you came to say, though.'],
  ['네','{네}?','They wait for the rest.'],['아니요','{네}?','They look confused.'],['몰라요','...{네}?','They wait.'],['저기요','{네}?','They wait for your question.']];
let TREPLY=null;
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
// a "present evidence" beat: pick something you've found to show them
async function present(nd,id){
  if(busy)return;sfx('tap');revealHeard();const hit=nd.shows.find(s=>s[0]===id);
  const e=ST.evidence[id];logLine({who:'narr',en:'You show them: '+plain(e.label)+'.'});
  go(hit?hit[1]:nd.miss);
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
  S.ch=id;useChapter(id);artKey=null;ambKey=null;lastLoc=null;BACK=[];
  if(restart){SEEN.clear();FILL={};PROOF={};pickQ=null;PMODE=null;for(const k in STRIKE)delete STRIKE[k];for(const k in HEARD)delete HEARD[k]} // half-filled answers don't carry into a fresh start
  if(p&&p.F&&p.F.started){
    CH_FIELDS.forEach(k=>S[k]=p[k]);
    if(!ST.places[S.loc])S.loc=ST.meta['start-place'];if(S.node&&!ST.nodes[S.node])S.node=null;
    revealFor=S.node;save();render();return;
  }
  S.F={started:1};S.cs={};S.visited={};S.node=null;S.loc=ST.meta['start-place'];
  stash();go(ST.meta.start);
}
const nextChapter=()=>WORLD.chapters[chIndex(S.ch)+1]||null;
