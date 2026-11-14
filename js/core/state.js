/* ============ STATE ============
   The save: what it holds, how old saves upgrade, how it is stored. */

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
