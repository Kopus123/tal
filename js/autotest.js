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
     camera                aim the camera at the target and take the photo
     phone THREAD          open the phone and read this thread
     map PLACE             travel by the village map
     solve ID a | b        fill a deduction on the case board and check it
     idle                  keep pressing Continue until you're free to look around
     expect COND           a flag condition that must be true now (same syntax as the story)
     done ID               this chapter must be finished                                      */
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

const STEPS={
  async chapter(id){S=fresh();S.set.auto=0;S.set.sound=0;BACK=[];SEEN.clear();
    document.querySelectorAll('.title').forEach(t=>t.remove());startChapter(id,true);await settle()},
  async choose(t){await clickEl(await until(()=>vis('#sf [data-ch]').find(b=>txt(b).includes(t)),`a choice "${t}"`))},
  async spot(l){await idle();const b=vis('#sb .chipbtn[data-hs]').find(b=>txt(b)===l);
    if(!b)fail(`no spot "${l}" here (spots: ${vis('#sb .chipbtn[data-hs]').map(txt).join(', ')||'none'})`);await clickEl(b)},
  async type(t){const inp=await until(()=>document.querySelector('#tin'),'a typed answer');inp.value=t;
    await clickEl(document.querySelector('#bSayT'));if(TFB)await clickEl(document.querySelector('#bNext'))},
  async build(a){await until(()=>document.querySelector('#sb .tiles'),'sentence tiles');
    for(const w of a.split('|').map(x=>x.trim())){const b=vis('#sb [data-t]').find(b=>!b.disabled&&plain(ST.nodes[S.node].tiles[+b.dataset.t])===plain(w));
      if(!b)fail(`no tile "${w}"`);await clickEl(b)}
    await clickEl(document.querySelector('#bSay'))},
  async present(id){await clickEl(await until(()=>document.querySelector(`#sb [data-show="${id}"]`),`a chance to show "${id}"`))},
  async contradict(a){const [x,y]=a.split('+').map(v=>v.trim());await until(()=>document.querySelector('#bClash'),'a contradiction');
    for(const k of[x,y]){const b=document.querySelector(`#sb [data-cx="${k}"]`);if(!b)fail(`"${k}" isn't on the list to pick`);await clickEl(b)}
    await clickEl(document.querySelector('#bClash'))},
  async number(v){await until(()=>document.querySelector('#sb .numpad'),'a number pad');
    for(const k of v.replace(/\D/g,'')){const b=document.querySelector(`#sb [data-nk="${k}"]`);await clickEl(b)}
    await clickEl(document.querySelector('#sb [data-nk="✓"]'))},
  async camera(){const sh=await until(()=>document.querySelector('#bShut'),'the camera');const nd=ST.nodes[S.node];
    cam={x:Math.max(0,nd.tx-22),y:Math.max(0,nd.ty-26)};await clickEl(sh);await tick(600);await settle()},
  async phone(id){openPhone();await settle();const b=document.querySelector(`[data-th="${id}"]`);if(!b)fail(`no phone thread "${id}"`);
    b.click();await settle();document.querySelectorAll('[data-vm]').forEach(v=>v.click());await settle();closeTop();await settle()},
  async map(p){await idle();openMap();await settle();const b=document.querySelector(`[data-pin="${p}"]`);
    if(!b){closeTop();fail(`"${p}" isn't on the map yet`)}b.click();await settle();
    if(S.loc!==p){closeTop();fail(`map didn't go to ${p}`)}},
  async solve(a){const [id,...rest]=a.split(/\s+/);const words=rest.join(' ').split('|').map(x=>x.trim());
    const q=ST.cases.find(x=>x.id===id);if(!q)fail(`no deduction ${id}`);if(!cond(q.c))fail(`deduction ${id} isn't on the board yet`);
    const wasFinal=q.final;document.querySelector('#bCase').click();await settle();   // the real top-bar button
    const open=document.querySelector(`[data-open="${id}"]`);if(!open)fail(`deduction ${id} can't be opened`);open.click();await settle();
    for(const w of words){const ti=document.querySelector('#ti');ti.value=w;ti.dispatchEvent(new Event('input'));
      document.querySelector('#ta').dispatchEvent(new Event('submit',{cancelable:true}));await settle()}
    document.querySelector(`[data-check="${id}"]`).click();await settle();
    if(!S.cs[id]&&!(wasFinal&&S.done[S.ch])){const m=document.querySelector('#cbb .miss');closeTop();fail(`deduction ${id} not accepted${m?' (Something doesn\'t follow)':''}`)}
    if(wasFinal){await tick(1200);await settle()}
    while(document.querySelector('#ovs .ov')){closeTop();await settle()}},
  async idle(){await idle()},
  async expect(c){if(!cond(c))fail(`expected ${c}`)},
  async done(id){if(!S.done[id])fail(`chapter ${id} isn't finished`)},
};

async function run(name){
  const r=await fetch(`tests/${name}.route`,{cache:'no-cache'});if(!r.ok){log(`FAIL ${name}: no route file`);failed=true;return}
  const lines=(await r.text()).split(/\r?\n/);let n=0;const t0=Date.now();
  for(let i=0;i<lines.length;i++){const line=lines[i].trim();if(!line||line.startsWith('#'))continue;
    const [cmd,...rest]=line.split(/\s+/);const arg=rest.join(' ');
    if(!STEPS[cmd]){log(`FAIL ${name}.route:${i+1}: unknown step "${cmd}"`);failed=true;return}
    try{await STEPS[cmd](arg);n++}
    catch(e){log(`FAIL ${name}.route:${i+1}: ${line}\n     ${e instanceof Fail?e.message:'crashed: '+(e&&e.stack||e)}\n     at ${where()}`);failed=true;return}
  }
  log(`ok   ${name}: ${n} steps`);
}
async function main(){
  window.speak=async()=>{};window.speakBuilt=async()=>{};window.sfx=()=>{};window.buzz=()=>{}; // silent and instant
  const errs=[];window.addEventListener('error',e=>errs.push(e.message));
  for(let i=0;i<400&&document.querySelector('#boot');i++)await tick(25);
  if(document.querySelector('#boot')){log('FAIL: the game never finished loading');failed=true}
  else for(const name of(new URLSearchParams(location.search).get('autotest')||'').split(',').filter(Boolean)){await run(name);if(failed)break}
  if(errs.length){log('page errors:\n  '+errs.join('\n  '));failed=true}
  const pre=document.createElement('pre');pre.id='autotest';pre.textContent=(failed?'FAIL':'PASS')+'\n'+out.join('\n');
  pre.style.cssText='position:fixed;inset:auto 0 0 0;z-index:9999;background:#000c;color:#fff;font:12px monospace;padding:8px;margin:0;white-space:pre-wrap';
  document.body.appendChild(pre);document.title=failed?'FAIL':'PASS';
}
main();
})();
