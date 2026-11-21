/* ============ AUTOMATIC PLAYTHROUGH ============
   Loaded only when the page is opened with ?autotest=prologue,ch1 (tools/playtest.py does this).
   Plays each route in tests/<name>.route by pressing the real buttons, the way a player would,
   and writes PASS or FAIL (with the step and scene where it got stuck) into the page.

   Route steps (one per line, # for comments). Before each step it presses Continue as needed.
     chapter ID            start this chapter fresh (erases progress)
     choose TEXT           press the choice whose text contains TEXT
     spot LABEL            press the hotspot with this exact label
     type 한국어            type an answer and press Say it
     build a | b | c       press these sentence tiles in order, then Say it
     present ID            show this piece of evidence
     number 9:00           press these digits on the number pad, then Say it
     contradict A + B      pick these two statements/evidence as the contradiction
     examine a | b         tap these details in a close-up, then Done looking
     camera                aim the camera at the target and take the photo
     phone THREAD          open the phone and read this thread
     map PLACE             travel by the village map
     solve ID a | b ; X + Y fill a deduction on the case board (and attach proof X and Y), check it
     nosolve ...           the same, but it must be rejected
     leave                 press Never mind (walk away from a decision)
     idle                  keep pressing Continue until you're free to look around
     expect COND           a condition that must be true now (same syntax as the story's "if")
     done ID               this chapter must be finished
   For testing the engine itself, not the story:
     fx EFFECTS            run story effects directly ("fx money +500; set g:x"); "fx @KEY ..." runs them
                           as if they came from the beat KEY, so once-only effects can be tested
     oldsave NAME          load tests/saves/NAME.json as if it were the save on the phone (it gets upgraded)
     note WORD TEXT        the notebook note for WORD must be exactly TEXT
     saved PATH            the save must hold something at this dotted path ("saved m.탈.u")
     used WORD [wrong]     count one right (or wrong) use of a word
     knows WORD N          the word's hint level must be N (0 full hints, 1 fading, 2 known)
     guess WORD right|wrong TEXT   Check my guess must judge TEXT that way for WORD
     shown SELECTOR [no]   that element must be visible on screen (or, with "no", hidden)
     nospot LABEL          that spot must NOT be offered here
     talk WHO              talk to a villager who is here now
     anychoice             press the first choice on offer
     closed PLACE          that place must turn you away right now
     wait                  press Wait a while (free time only)
     sleep                 press Go to bed (at home, evening or night)
     switch ID             move to this chapter keeping the save, the way the story does at a chapter's end
     job ID                take this job from the notice board (you must be at the board's place)
     noboard ID            this job must NOT be on the notice board right now
     encounters on|off     village encounters (off from the start of every route, so they don't interrupt it)  */
(function(){
const out=[];let failed=false;
const log=s=>out.push(s);
const tick=(ms=0)=>new Promise(r=>setTimeout(r,ms));
const vis=sel=>[...document.querySelectorAll(sel)];
const txt=el=>(el.textContent||'').replace(/\s+/g,' ').trim();
function where(){const nd=S.node&&ST.nodes[S.node];
  return `chapter ${S.ch}, place ${S.loc}, scene ${S.node||'(looking around)'}${nd&&(nd.ko||nd.en)?` "${plain(nd.ko||nd.en).slice(0,60)}"`:''}`}
class Fail extends Error{}
const fail=m=>{throw new Fail(m)};
async function settle(){for(let i=0;i<200;i++){await tick(20);if(!busy&&!document.querySelector('.rewinding'))return}fail('stuck while busy')}
async function clickEl(el){el.click();await settle()}
// press Continue until find() returns something; a closed overlay never blocks
async function until(find,what){
  for(let i=0;i<120;i++){
    const el=find();if(el)return el;
    const ov=document.querySelector('#ovs .ov');if(ov){closeTop();await settle();continue}
    const n=document.querySelector('#bNext');if(n){await clickEl(n);continue}
    fail(`never reached ${what}`);
  }
  fail(`gave up waiting for ${what}`);
}
async function idle(){for(let i=0;i<120&&S.node;i++){const n=document.querySelector('#bNext');
  if(!n)fail('needs a decision before it can go on');await clickEl(n)}if(S.node)fail('never finished the scene')}

// solve ID w1 | w2 ; proofA + proofB   (nosolve = the same, but it must be rejected)
async function solveIt(a,expectFail){
  const [wpart,ppart]=a.split(';');const [id,...rest]=wpart.trim().split(/\s+/);const words=rest.join(' ').split('|').map(x=>x.trim()).filter(Boolean);
  const proofs=ppart?ppart.split('+').map(x=>x.trim()):[];
  const q=ST.cases.find(x=>x.id===id);if(!q)fail(`no deduction ${id}`);if(!cond(q.c))fail(`deduction ${id} isn't on the board yet`);
  const wasFinal=q.final,chBefore=S.ch;document.querySelector('#bCase').click();await settle();   // the real top-bar button
  const open=document.querySelector(`[data-open="${id}"]`);if(open){open.click();await settle()}else if(pickQ!==id)fail(`deduction ${id} can't be opened`);
  for(const w of words){const ti=document.querySelector('#ti');ti.value=w;ti.dispatchEvent(new Event('input'));
    document.querySelector('#ta').dispatchEvent(new Event('submit',{cancelable:true}));await settle()}
  for(let i=0;i<proofs.length;i++){const s=document.querySelector(`[data-ps="${i}"]`);if(!s)fail(`deduction ${id} has no proof slot ${i+1}`);if(!s.classList.contains('active')){s.click();await settle()}
    const b=document.querySelector(`[data-pp="${proofs[i]}"]`);if(!b)fail(`"${proofs[i]}" isn't available as proof`);b.click();await settle()}
  document.querySelector(`[data-check="${id}"]`).click();await settle();
  const ok=S.cs[id]||(wasFinal&&S.done[chBefore]);
  if(expectFail){if(ok)fail(`deduction ${id} was accepted but shouldn't be`);document.querySelector(`[data-clear="${id}"]`).click();await settle()}
  else if(!ok){const m=document.querySelector('#cbb .miss');closeTop();fail(`deduction ${id} not accepted${m?' (Something doesn\'t follow)':''}`)}
  if(wasFinal&&!expectFail){await tick(1200);await settle()}
  while(document.querySelector('#ovs .ov')){closeTop();await settle()}
}
const STEPS={
  async chapter(id){ENC_OFF=true;S=fresh();S.set.auto=0;S.set.sound=0;S.set.music=0;S.set.amb=0;BACK=[];SEEN.clear();
    document.querySelectorAll('.title').forEach(t=>t.remove());startChapter(id,true);await settle()},
  async choose(t){await clickEl(await until(()=>vis('#sf [data-ch]').find(b=>txt(b).includes(t)),`a choice "${t}"`))},
  async spot(l){await idle();const b=vis('#sb .chipbtn[data-hs]').find(b=>txt(b)===l);
    if(!b)fail(`no spot "${l}" here (spots: ${vis('#sb .chipbtn[data-hs]').map(txt).join(', ')||'none'})`);await clickEl(b)},
  async type(t){const inp=await until(()=>document.querySelector('#tin'),'a typed answer');inp.value=t;
    await clickEl(document.querySelector('#bSayT'));if(TFB)await clickEl(document.querySelector('#bNext'))},
  async build(a){await until(()=>document.querySelector('#sb .tiles'),'sentence tiles');
    for(const w of splitBar(a)){const b=vis('#sb [data-t]').find(b=>!b.disabled&&plain(ST.nodes[S.node].tiles[+b.dataset.t])===plain(w));
      if(!b)fail(`no tile "${w}"`);await clickEl(b)}
    await clickEl(document.querySelector('#bSay'))},
  async present(id){await clickEl(await until(()=>document.querySelector(`#sb [data-show="${id}"]`),`a chance to show "${id}"`))},
  async contradict(a){const [x,y]=a.split('+').map(v=>v.trim());await until(()=>document.querySelector('#bClash'),'a contradiction');
    for(const k of[x,y]){const b=document.querySelector(`#sb [data-cx="${k}"]`);if(!b)fail(`"${k}" isn't on the list to pick`);await clickEl(b)}
    await clickEl(document.querySelector('#bClash'))},
  async number(v){await until(()=>document.querySelector('#sb .numpad'),'a number pad');
    for(const k of v.replace(/\D/g,'')){const b=document.querySelector(`#sb [data-nk="${k}"]`);await clickEl(b)}
    await clickEl(document.querySelector('#sb [data-nk="✓"]'))},
  async examine(a){await until(()=>document.querySelector('#exam'),'a close-up');const x=ST.examines[ST.nodes[S.node].exam];
    for(const id of a.split('|').map(v=>v.trim())){const d=x.details.find(d=>d.id===id);if(!d)fail(`no detail "${id}"`);
      const ex=document.querySelector('#exam'),r=ex.getBoundingClientRect();
      ex.dispatchEvent(new MouseEvent('click',{bubbles:true,clientX:r.left+r.width*d.x/100,clientY:r.top+r.height*d.y/100}));await settle();
      if(!S.F['ex_'+x.id+'_'+id])fail(`tapping "${id}" didn't find it`)}
    const b=document.querySelector('#bNext');if(!b||b.disabled)fail('the close-up still wants more details');await clickEl(b)},
  async camera(){const sh=await until(()=>document.querySelector('#bShut'),'the camera');const nd=ST.nodes[S.node];
    cam={x:Math.max(0,nd.tx-22),y:Math.max(0,nd.ty-26)};await clickEl(sh);await tick(600);await settle()},
  async phone(id){openPhone();await settle();const b=document.querySelector(`[data-th="${id}"]`);if(!b)fail(`no phone thread "${id}"`);
    b.click();await settle();document.querySelectorAll('[data-vm]').forEach(v=>v.click());await settle();closeTop();await settle()},
  async map(p){await idle();openMap();await settle();const b=document.querySelector(`[data-pin="${p}"]`);
    if(!b){closeTop();fail(`"${p}" isn't on the map yet`)}b.click();await settle();
    if(S.loc!==p){closeTop();fail(`map didn't go to ${p}`)}},
  async solve(a){await solveIt(a,false)},
  async nosolve(a){await solveIt(a,true)},
  async idle(){await idle()},
  async leave(){const b=await until(()=>document.querySelector('#bLeave'),'a Never mind button');await clickEl(b)},
  async expect(c){if(!cond(c))fail(`expected ${c}`)},
  async done(id){if(!S.done[id])fail(`chapter ${id} isn't finished`)},
  async nospot(l){await idle();if(vis('#sb .chipbtn[data-hs]').some(b=>txt(b)===l))fail(`"${l}" is offered here but shouldn't be`)},
  // people move around (a different spot each day), so "talk" first walks to wherever they are now, if they're anywhere
  async talk(who){await idle();let b=document.querySelector(`#sb [data-who="${who}"]`);
    const w=!b&&PEOPLE[who]&&whereNow(PEOPLE[who]);if(w&&w.place!==S.loc&&canTravel()&&S.known[w.place]){await STEPS.map(w.place);await idle();b=document.querySelector(`#sb [data-who="${who}"]`)}
    if(!b)fail(`${who} isn't here now (here: ${vis('#sb [data-who]').map(x=>x.dataset.who).join(', ')||'nobody'})`);await clickEl(b)},
  async anychoice(){await clickEl(await until(()=>vis('#sf [data-ch]')[0],'a choice'))},
  async job(id){await idle();const b=vis('#sb .chipbtn[data-hs]').find(b=>txt(b)==='Notice board');if(!b)fail('no notice board here');await clickEl(b);
    const t=document.querySelector(`[data-take="${id}"]`);const on=vis('[data-take]').map(x=>x.dataset.take);
    if(!t){closeTop();await settle();fail(`job "${id}" isn't on the board (on it: ${on.join(', ')||'nothing'}${S.world.job?'; already working on '+S.world.job:''})`)}await clickEl(t)},
  async noboard(id){if(jobsToday().some(j=>j.id===id))fail(`job "${id}" is on the board, but shouldn't be`)},
  async encounters(a){ENC_OFF=a.trim()!=='on'},
  async closed(p){await idle();const before=S.loc;if(enter(p)!==false||S.loc!==before)fail(`${p} let you in, but it should be closed`)},
  async wait(){await idle();const b=document.querySelector('#bWait');if(!b)fail('there is no Wait button here (is the clock running, and is it before night?)');await clickEl(b)},
  async sleep(){await idle();const b=document.querySelector('#bBed');if(!b)fail('there is no Go to bed button here (home, evening or night, clock running)');await clickEl(b)},
  async shown(a){const [sel,how]=a.split(/\s+/);const el=document.querySelector(sel);if(!el)fail(`nothing matches ${sel}`);
    const vis=getComputedStyle(el).display!=='none';if(vis!==(how!=='no'))fail(`${sel} is ${vis?'showing':'hidden'} on screen`)},
  async guess(a){const m=a.match(/^(\S+)\s+(right|wrong)\s+(.+)$/);if(!m)fail('guess WORD right|wrong TEXT');
    const got=guessRight(m[3],meaningOf(m[1]));if(got!==(m[2]==='right'))fail(`"${m[3]}" for ${m[1]} (${meaningOf(m[1])}) was judged ${got?'right':'wrong'}`)},
  async used(a){const [w,how]=a.split(/\s+/);if(!W[w])fail(`${w} isn't a word`);noteUsed('{'+w+'}',how!=='wrong')},
  async knows(a){const [w,n]=a.split(/\s+/);if(knowLevel(w)!==+n)fail(`${w} is at hint level ${knowLevel(w)}, expected ${n}`)},
  async switch(id){if(!CH[id])fail(`no chapter ${id}`);startChapter(id,true);await settle()},
  async saved(path){let v=S;for(const k of path.split('.')){v=v==null?v:v[k]}if(!v)fail(`the save has nothing at ${path}`)},
  async fx(a){const k=a.match(/^@(\S+)\s+(.+)$/);
    const list=(k?k[2]:a).split(';').map(x=>x.trim()).filter(Boolean).map(x=>{const m=x.match(/^(\w+)\s+(.+?)(?:\s+if\s+(\S+))?$/);
      if(!m)fail(`effect not understood: ${x}`);if(!EFFECTS[m[1]])fail(`no effect called "${m[1]}"`);return {k:m[1],a:m[2].trim(),c:m[3]}});
    runFx(list,k?{key:k[1]}:{});save()},
  async oldsave(name){const r=await fetch(`tests/saves/${name}.json`,{cache:'no-cache'});if(!r.ok)fail(`no tests/saves/${name}.json`);
    S=adopt(await r.json());S.set.auto=0;S.set.sound=0;BACK=[];SEEN.clear();
    if(S.v!==SAVE_V)fail(`the save stopped at format ${S.v}, the game is at ${SAVE_V}: a MIGRATE step is missing`);
    document.querySelectorAll('.title').forEach(t=>t.remove());resume();render();await settle()},
  async note(a){const [w,...rest]=a.split(/\s+/);const want=rest.join(' '),got=(S.w[w]||{}).note;
    if(got!==want)fail(`the note for ${w} is ${got===undefined?'missing':'"'+got+'"'}, expected "${want}"`)},
};

let JUMPING=false;
async function run(name,stopAt,onMark){
  const r=await fetch(`tests/${name}.route`,{cache:'no-cache'});if(!r.ok){log(`FAIL ${name}: no route file`);failed=true;return}
  const lines=(await r.text()).split(/\r?\n/);let n=0;const t0=Date.now();
  const target=stopAt?Math.max(1,lines.findIndex(l=>l.trim().startsWith('#@')&&l.trim().slice(2).trim()===stopAt)):0;
  for(let i=0;i<lines.length;i++){const line=lines[i].trim();
    if(target&&window.__jumpBar)window.__jumpBar.style.width=Math.min(100,i/target*100)+'%';
    if(stopAt&&line.startsWith('#@')&&line.slice(2).trim()===stopAt)return 'stopped';
    if(onMark&&line.startsWith('#@')){await idle().catch(()=>{});await onMark(line.slice(2).trim())}
    if(!line||line.startsWith('#'))continue;
    const [cmd,...rest]=line.split(/\s+/);const arg=rest.join(' ');
    if(!STEPS[cmd]){log(`FAIL ${name}.route:${i+1}: unknown step "${cmd}"`);failed=true;return}
    try{await STEPS[cmd](arg);n++}
    catch(e){log(`FAIL ${name}.route:${i+1}: ${line}\n     ${e instanceof Fail?e.message:'crashed: '+(e&&e.stack||e)}\n     at ${where()}`);failed=true;return}
  }
  log(`ok   ${name}: ${n} steps`);
}
const REAL={};
function silence(){['speak','speakBuilt','sfx','buzz','toast'].forEach(k=>REAL[k]=window[k]);
  window.speak=async()=>{};window.speakBuilt=async()=>{};window.sfx=()=>{};window.buzz=()=>{}}
function unsilence(){Object.assign(window,REAL)}
// playtest: play the route up to a '#@ label' checkpoint, then hand the game back (notebook as it was)
async function jump(route,label){
  const keep=JSON.parse(JSON.stringify({set:S.set,w:S.w,nb:S.nb,m:S.m,tl:S.tl,mx:S.mx}));
  silence();window.toast=()=>{};JUMPING=true;out.length=0;failed=false;
  const realST=window.setTimeout;window.setTimeout=(f,ms,...x)=>realST(f,Math.min(ms||0,4),...x); // pauses become instant while jumping
  const veil=document.createElement('div');veil.className='ov center';veil.innerHTML=`<div class="panel paper" style="padding:20px;text-align:center;min-width:260px">Jumping ahead to<br><b>${esc(label)}</b><div class="jbar"><i id="jbar"></i></div></div>`;document.body.appendChild(veil);
  window.__jumpBar=veil.querySelector('#jbar');
  let r;try{r=await run(route,label)}catch(e){out.push(String(e))}
  window.setTimeout=realST;veil.remove();unsilence();JUMPING=false;ENC_OFF=false;
  while(document.querySelector('#ovs .ov'))closeTop();
  const met=S.w;Object.assign(S,keep);for(const k in met)if(!S.w[k])S.w[k]={ctx:met[k].ctx||[],note:'',n:met[k].n||1}; // words from skipped scenes, without notes
  save();lastLoc=null;render();
  if(r==='stopped')toast('Jumped to: '+esc(label),3500);else toast('Jump failed: '+esc(out.join(' ')).slice(0,300),9000);
}
/* ============ RANDOM PLAY ("fuzz", tools/fuzz.py) ============
   Plays the solution route, and at every '#@' checkpoint stops to tap around at random from there:
   R runs of N taps each, each run starting from the checkpoint again. After every tap it checks the game
   for things that should never happen (errors, nothing to tap, text off the screen, buttons on top of
   each other, raw markup on screen, the clock going backwards, standing inside a closed place, a save
   that doesn't come back the same). Every run is seeded, so a problem can be replayed exactly. */
let rnd=Math.random;
function seed(n){let a=n>>>0;rnd=()=>{a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};Math.random=rnd}
const pick=a=>a[Math.floor(rnd()*a.length)];
const NEVER='#tn,#rs,[data-new],[data-ask],[data-jump],a';   // erase-progress buttons, Jump ahead, links out
const shown=el=>{if(!el.isConnected||el.disabled)return false;const r=el.getBoundingClientRect();if(r.width<2||r.height<2)return false;
  const cs=getComputedStyle(el);return cs.visibility!=='hidden'&&cs.pointerEvents!=='none'&&!el.closest('[hidden]')};
const label=el=>{const t=txt(el).slice(0,40);return t?`"${t}"`:'#'+(el.id||[...el.classList].join('.')||el.tagName.toLowerCase())+(el.dataset&&Object.keys(el.dataset).length?'['+Object.entries(el.dataset).map(([k,v])=>k+'='+v).join(',')+']':'')};
const RANDOM_TEXT=()=>pick(['','ㅋ','hello','네',pick(Object.keys(W)),pick(Object.keys(W))+' '+pick(Object.keys(W)),'123','  ','grandma','?']);
function topLayer(){const t=document.querySelector('.title');if(t)return t;return document.querySelector('#ovs .ov:last-child')||document.querySelector('#ovs > :last-child')||null}
function choices(){
  const layer=topLayer();const root=layer||document;
  const bs=[...root.querySelectorAll('button')].filter(b=>!b.matches(NEVER)&&!b.closest(NEVER)&&shown(b)&&(layer||!b.closest('#ovs')));
  const acts=bs.map(b=>{let w=1;
    if(b.id==='bNext')w=12;else if(b.closest('#sf'))w=5;else if(b.matches('.chipbtn,[data-who],[data-pin]'))w=4;
    else if(b.closest('.bar'))w=.6;else if(b.matches('.w,[data-w],[data-name]'))w=1.2;
    return{w,d:'tap '+label(b),f:async()=>{b.click();await settle()}}});
  const inputs=[...root.querySelectorAll('input[type=text],input:not([type]),textarea')].filter(shown);
  for(const inp of inputs)acts.push({w:2,d:'type into '+label(inp),f:async()=>{const v=RANDOM_TEXT();inp.value=v;inp.dispatchEvent(new Event('input',{bubbles:true}));
    const form=inp.closest('form');if(form&&rnd()<.6)form.dispatchEvent(new Event('submit',{cancelable:true}));await settle();return v}});
  const ex=document.querySelector('#exam');
  if(ex&&!layer&&shown(ex))acts.push({w:6,d:'tap the close-up',f:async()=>{const r=ex.getBoundingClientRect(),x=rnd(),y=rnd();
    ex.dispatchEvent(new MouseEvent('click',{bubbles:true,clientX:r.left+r.width*x,clientY:r.top+r.height*y}));await settle();return `${Math.round(x*100)}%,${Math.round(y*100)}%`}});
  if(document.querySelector('#bShut')&&!layer)acts.push({w:2,d:'aim the camera',f:async()=>{cam={x:Math.floor(rnd()*70),y:Math.floor(rnd()*70)};await settle();return `${cam.x},${cam.y}`}});
  if(layer&&!layer.matches('.title'))acts.push({w:Math.max(2,bs.length/3),d:'close the panel',f:async()=>{closeTop();await settle()}});
  return acts}
function choose(acts){let s=acts.reduce((a,x)=>a+x.w,0)*rnd();for(const a of acts){if((s-=a.w)<=0)return a}return acts[acts.length-1]}
const clockNow=()=>S.world?S.world.day*10+S.world.slot:0;
const RAW=/\bundefined\b|\bNaN\b|\[object |\$\{|\{[^{}\s]{1,20}\}|<\/?[a-z]+[ >]/;
// everything that should always be true; returns a list of problems
function checks(ctx){
  const bad=[];document.getAnimations().forEach(a=>{try{a.finish()}catch(e){}});
  const layer=topLayer();
  // 1. text that is markup or a bug leaking onto the screen
  for(const root of[document.querySelector('#app'),layer].filter(Boolean)){const t=root.innerText||'';const m=t.match(RAW);
    if(m){const i=t.indexOf(m[0]);bad.push(`raw text on screen: "…${t.slice(Math.max(0,i-30),i+30).replace(/\s+/g,' ')}…"`)}}
  // 2. off the edge of a phone screen
  const W0=innerWidth;if(document.documentElement.scrollWidth>W0+1)bad.push(`the page scrolls sideways (${document.documentElement.scrollWidth}px wide on a ${W0}px screen)`);
  for(const el of(layer||document.querySelector('#app')).querySelectorAll('button,.w,h1,h2,h3,p,.chip,b')){if(!shown(el))continue;
    let sc=el.parentElement;let clipped=false;while(sc&&sc!==document.body){const o=getComputedStyle(sc).overflowX;if(o==='auto'||o==='scroll'||o==='hidden'&&sc.scrollWidth>sc.clientWidth+1&&!sc.matches('.map,.artwrap,.scene')){clipped=true;break}sc=sc.parentElement}
    if(clipped)continue;const r=el.getBoundingClientRect();
    if(r.right>W0+2||r.left<-2){bad.push(`${label(el)} sticks out of the screen (${Math.round(r.left)}–${Math.round(r.right)}px of ${W0})`);break}}
  // 3. things you tap drawn on top of each other (same kind only: pins with pins, spots with spots, choices with choices)
  const kinds=['.pin','.pin b','.hs','#sf button','#sb .chipbtn','.tiles button','[data-who]'];
  for(const k of kinds){const els=[...(layer||document).querySelectorAll(k)].filter(shown).map(e=>[e,e.getBoundingClientRect()]);
    for(let i=0;i<els.length;i++)for(let j=i+1;j<els.length;j++){const[a,ra]=els[i],[b,rb]=els[j];if(a.contains(b)||b.contains(a))continue;
      const ix=Math.min(ra.right,rb.right)-Math.max(ra.left,rb.left),iy=Math.min(ra.bottom,rb.bottom)-Math.max(ra.top,rb.top);
      if(ix>3&&iy>3&&ix*iy>.2*Math.min(ra.width*ra.height,rb.width*rb.height))bad.push(`${label(a)} and ${label(b)} overlap (${k})`)}}
  if(!layer){
    // 4. stuck: nothing to tap below the picture
    const any=[...document.querySelectorAll('#sb button,#sf button,#sb input,#exam,#bShut')].some(shown);
    if(!any)bad.push('nothing to tap: no buttons under the picture');
    // 5. standing in a place that is closed
    if(!S.node&&ST&&ST.free&&isClosed(S.loc))bad.push(`standing inside ${S.loc}, which is closed right now`);
  }
  // 6. the clock only goes forwards
  const c=clockNow();if(ctx.clock!=null&&c<ctx.clock&&!ctx.rewound)bad.push(`the clock went backwards (day ${Math.floor(ctx.clock/10)} slot ${ctx.clock%10} → day ${S.world.day} slot ${S.world.slot})`);ctx.clock=c;
  // 7. tappable words that have no notebook page
  for(const el of document.querySelectorAll('[data-w]'))if(shown(el)&&!W[el.dataset.w]){bad.push(`the word "${el.dataset.w}" can be tapped but has no notebook page`);break}
  // 8. the save comes back the same
  if(ctx.n%15===0){const a=JSON.stringify(S),b=JSON.stringify(adopt(JSON.parse(a)));if(a!==b){let i=0;while(a[i]===b[i])i++;bad.push(`the save changes when it's loaded back: …${a.slice(Math.max(0,i-60),i+40)}… became …${b.slice(Math.max(0,i-60),i+40)}…`)}}
  return bad}
async function fuzzFrom(mark,snap,runs,steps,base,found,cover){
  for(let r=0;r<runs;r++){
    const sd=base*1000+FUZZ_MARK*50+r;seed(sd);ENC_OFF=false;
    await restore(snap);
    const trail=[],ctx={clock:clockNow(),n:0};const errs=[];const onErr=e=>errs.push(e.message||String(e.reason));
    window.addEventListener('error',onErr);window.addEventListener('unhandledrejection',onErr);
    for(let n=0;n<steps;n++){ctx.n=n;
      if(S.node)cover.scenes.add(S.node);
      const acts=choices();if(!acts.length){report('nothing at all to tap',mark,sd,n,trail,found);break}
      const a=choose(acts);ctx.rewound=/‹ Back|Chapters|#bBack|Continue ·/.test(a.d);let extra;
      try{extra=await a.f()}catch(e){errs.push(e instanceof Fail?e.message:(e&&e.stack||String(e)).split('\n').slice(0,3).join(' | '))}
      trail.push(a.d+(extra!==undefined?` → ${JSON.stringify(extra)}`:''));if(trail.length>14)trail.shift();
      for(const e of errs.splice(0))report('error: '+e,mark,sd,n,trail,found);
      let bad=[];try{bad=checks(ctx)}catch(e){bad=['the checks crashed: '+e.message]}
      for(const b of bad)report(b,mark,sd,n,trail,found);
      if(bad.some(b=>b.startsWith('nothing to tap'))||document.querySelector('.title')&&!S.F.started)break;
    }
    window.removeEventListener('error',onErr);window.removeEventListener('unhandledrejection',onErr);
  }
}
let FUZZ_MARK=0;
// back to a checkpoint: the save, and the half-done things kept outside it (case board, strikes)
async function restore(snap){
  while(document.querySelector('#ovs .ov'))closeTop();document.querySelectorAll('.title').forEach(t=>t.remove());
  S=adopt(JSON.parse(snap));S.set.auto=0;S.set.sound=0;S.set.music=0;S.set.amb=0;BACK=[];SEEN.clear();
  FILL={};PROOF={};pickQ=null;PMODE=null;boardTab='ded';for(const k in STRIKE)delete STRIKE[k];for(const k in HEARD)delete HEARD[k];
  resume();lastLoc=null;render();await settle()}
function report(msg,mark,sd,n,trail,found){const key=msg.replace(/\d+(px|%)?/g,'#');if(found.has(key)){found.get(key).times++;return}
  found.set(key,{msg,mark,seed:sd,step:n+1,trail:trail.slice(),at:where(),times:1})}
async function fuzz(route,runs,steps,base,only){
  const found=new Map(),cover={scenes:new Set()};const t0=Date.now();let marks=0;
  const realST=window.setTimeout;window.setTimeout=(f,ms,...x)=>realST(f,Math.min(ms||0,4),...x);  // pauses are instant
  await run(route,null,async mark=>{FUZZ_MARK++;if(only&&mark!==only)return;marks++;
    const snap=JSON.stringify(S),realRnd=Math.random,encWas=ENC_OFF;
    await fuzzFrom(mark,snap,runs,steps,base,found,cover);
    Math.random=realRnd;ENC_OFF=encWas;await restore(snap)});   // back on the route
  window.setTimeout=realST;
  const all=new Set([...Object.values(CH).flatMap(c=>Object.keys(c.nodes||{})),...Object.keys(PNODES)]);
  const hit=[...cover.scenes].filter(s=>all.has(s)).length;
  log(`random play: ${marks} checkpoints × ${runs} runs × up to ${steps} taps, ${Math.round((Date.now()-t0)/1000)}s; reached ${hit} of ${all.size} story beats`);
  if(!found.size){log('no problems found');return}
  failed=true;log(`${found.size} problem${found.size>1?'s':''}:`);let i=0;
  for(const f of found.values()){i++;log(`\n${i}. ${f.msg}${f.times>1?`  (seen ${f.times} times)`:''}\n   from checkpoint "${f.mark}", seed ${f.seed}, tap ${f.step}; ${f.at}\n   last taps:\n     ${f.trail.join('\n     ')}`)}
}
window.TAL_TEST={jump};
async function main(){
  silence(); // silent and instant
  const errs=[];window.addEventListener('error',e=>errs.push(e.message));
  for(let i=0;i<400&&document.querySelector('#boot');i++)await tick(25);
  if(document.querySelector('#boot')){log('FAIL: the game never finished loading');failed=true}
  else if(PARSE_WARN.length){log('FAIL: the game could not read these story lines:\n  '+PARSE_WARN.join('\n  '));failed=true}
  else if(new URLSearchParams(location.search).get('fuzz')){const q=new URLSearchParams(location.search);const [base,runs,steps]=q.get('fuzz').split(',').map(Number);
    await fuzz(q.get('autotest'),runs||6,steps||150,base||1,q.get('only')||'')}
  else for(const name of(new URLSearchParams(location.search).get('autotest')||'').split(',').filter(Boolean)){await run(name);if(failed)break}
  if(errs.length){log('page errors:\n  '+errs.join('\n  '));failed=true}
  const pre=document.createElement('pre');pre.id='autotest';pre.textContent=(failed?'FAIL':'PASS')+'\n'+out.join('\n');
  pre.style.cssText='position:fixed;inset:auto 0 0 0;z-index:9999;background:#000c;color:#fff;font:12px monospace;padding:8px;margin:0;white-space:pre-wrap';
  document.body.appendChild(pre);document.title=failed?'FAIL':'PASS';
}
if(/[?&]autotest=/.test(location.search))main();
})();
