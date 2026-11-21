/* ============ JOBS ============
   Small detective jobs from the notice board in the village hall (마을회관), for free days.
   Each one is written in a story file as:

     === job ID
     title 잃어버린 가방 | The lost bag
     level easy                      (easy or medium: shown on the board)
     client WHO                      (who it's for: they pay, and like you more)
     pay 5000                        (won, when it's done)
     thanks 2                        (friendship with the client, when it's done)
     when COND                       (optional: only on the board while COND holds)
     note One line for the board, in English. No spoilers.
     start SCENE                     (taking the job plays this)
     ask WHO SCENE                   (while you're on this job, WHO has "About the job" in their talk menu)

   In its scenes:  ! job done   (paid, thanked, off the board for good)
                   ! job fail   (the client gives up for today; it comes back on the board another day)
   Conditions:     job:ID (you're on it now)     jobdone:ID (finished it before)
   Flags, evidence and statements a job uses start with its ID and "_" (bag_seen, ev bag_bag, st bag_jiho):
   taking the job again clears them, so a failed job starts over clean.  */

const jobOn=()=>S.world.job&&ST&&ST.jobs&&ST.jobs[S.world.job]||null;
const jobState=id=>S.world.jobs[id]||{};
// the board today: up to 3 jobs, shuffled by the day so it changes, never one you finished or failed today
function jobsToday(){
  const h=s=>{let a=[...s].reduce((a,c)=>Math.imul(a^c.charCodeAt(0),16777619)>>>0,2166136261);a^=a>>>16;a=Math.imul(a,0x45d9f3b)>>>0;return(a^a>>>16)>>>0};
  return Object.values(ST.jobs||{}).filter(j=>!jobState(j.id).done&&jobState(j.id).failed!==S.world.day&&S.world.job!==j.id&&cond(j.when))
    .sort((a,b)=>h(S.world.day+':'+a.id)-h(S.world.day+':'+b.id)).slice(0,3)}
function takeJob(id){const j=ST.jobs[id];if(!j||S.world.job)return;
  S.world.job=id;const re=new RegExp('^(ev_|st_|ex_)?'+id+'_');Object.keys(S.F).forEach(k=>{if(re.test(k))delete S.F[k]});
  save();go(j.start)}
const wonStr=n=>(+n).toLocaleString('en-US')+'원';
defEffect('job','job',a=>{const j=jobOn();if(!j)return;const w=S.world;
  if(a==='done'){w.jobs[j.id]={done:w.day};w.job=null;w.money+=j.pay;addRel(j.client,j.thanks);sfx('solve');
    toast(`Job done: <b>${esc(j.en)}</b><br>+${wonStr(j.pay)}`,4500)}
  else if(a==='fail'){w.jobs[j.id]={failed:w.day};w.job=null;sfx('wrong');
    toast(`The job's off for today: <b>${esc(j.en)}</b>.<br>It'll be back on the board another day.`,5000)}});
defCond('job:','job',id=>S.world.job===id);
defCond('jobdone:','job',id=>!!jobState(id).done);
