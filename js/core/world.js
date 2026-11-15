/* ============ THE WORLD ============
   What carries on between chapters (S.world): the day and time of day, money, friendships,
   things you own, village flags. This file only gives story files the words for it.
   Nothing in the game uses them yet: time, villagers, the shop and your room build on these.

     ! money +500          ! money -200          ! money =1000
     ! rel sujin +1        (friendship with someone from the cast)
     ! item +radio         ! item -radio         (things you own; more than one adds up)
     ! set g:metKid        (a village flag: like a normal flag, but kept between chapters)
   money, rel and item happen once per beat, however often you pass it. For a price you pay on
   every visit, end it with "each time":   ! money -1500 each time

     if money>=500    if day>=3    if time:evening    if rel:sujin>=2    if has:radio    if g:metKid

   THE CLOCK.  A day has four steps: morning, afternoon, evening, night. Sleeping starts the next morning.
     ! time stop           the story holds the clock: only the story changes the time now
     ! time go             the story lets go: time passes when you wait, travel or sleep
     ! time set evening    the story says what time it is
     ! time sleep          the next morning (a new day)
     ! time +1             one step later, if the clock is running (use "each time" for a bus ride)
     if clock              the clock is running            if on:market    today is that calendar entry   */

const SLOTS=['morning','afternoon','evening','night'];
const amount=a=>{const m=String(a).trim().match(/^([+\-=]?)(\d+)$/);return m?{op:m[1]||'+',n:+m[2]}:null};
const bump=(v,am)=>am.op==='='?am.n:Math.max(0,v+(am.op==='-'?-am.n:am.n));

defCond('money','number',()=>S.world.money);
defCond('day','number',()=>S.world.day);
defCond('time:','slot',s=>SLOTS[S.world.slot]===s);
defCond('g:','gflag',f=>S.world.g[f]);
defCond('rel:','who',w=>S.world.rel[w]||0);
defCond('has:','item',it=>S.world.inv[it]||0);

defEffect('money','amount',a=>{const am=amount(a);if(am)S.world.money=bump(S.world.money,am)},{once:1});
defEffect('rel','who_amount',a=>{const [w,n]=a.trim().split(/\s+/),am=amount(n);if(!w||!am)return;if(am.op==='=')S.world.rel[w]=am.n;else addRel(w,am.op==='-'?-am.n:am.n)},{once:1});
defEffect('item','item',a=>{const m=a.trim().match(/^([+-]?)(\S+)$/);if(!m)return;
  const n=Math.max(0,(S.world.inv[m[2]]||0)+(m[1]==='-'?-1:1));if(n)S.world.inv[m[2]]=n;else delete S.world.inv[m[2]]},{once:1});

/* ---------- the clock ---------- */
const SLOT_KO={morning:'아침',afternoon:'낮',evening:'저녁',night:'밤'};
const slotName=()=>SLOTS[S.world.slot]||'morning';
let TIMECARD=false;                       // show the big time-of-day card on the next draw
// what the calendar says about a day
const eventsOn=day=>(WORLD.calendar||[]).filter(e=>e.day?e.day===day:day>=e.from&&(day-e.from)%e.every===0);
function passTime(){if(S.world.frozen||S.world.slot>=3)return false;missEvents();S.world.slot++;TIMECARD=true;closingTime();save();checkEvents();return true}
// where a spot takes you: "=> place X" directly, or a scene ("-> v_back") that moves you with "! place X"
function spotExit(x){const m=x.t.match(/^place\s+(\S+)/);if(m)return m[1];if(!/^\w+$/.test(x.t))return null;
  for(let i=1,id=x.t;ST.nodes[id];id=x.t+'.'+(++i)){const f=(ST.nodes[id].fx||[]).find(f=>f.k==='place');if(f)return f.a.trim()}return null}
// if the place you're in has just closed, you're shown out to the first place its exits lead to (walking, or the bus)
function closingTime(){if(!ST||!isClosed(S.loc))return;const l=ST.places[S.loc];
  const out=l.spots.map(spotExit).find(p=>p&&ST.places[p]&&!isClosed(p));if(!out)return;
  toast(esc(l.closed.t)+' You head back outside.',4500);S.loc=out}
function nextMorning(){missEvents();S.world.day++;S.world.slot=0;TIMECARD=true;save()}

defCond('clock','bool',()=>!S.world.frozen);
defCond('on:','calendar',id=>eventsOn(S.world.day).some(e=>e.id===id));
defEffect('time','time',a=>{const m=a.trim().match(/^(stop|go|sleep|\+\d+|set\s+(\w+))$/);if(!m)return;
  if(a==='stop')S.world.frozen=1;else if(a==='go')S.world.frozen=0;else if(a==='sleep')nextMorning();
  else if(m[2]){const i=SLOTS.indexOf(m[2]);if(i>=0&&i!==S.world.slot){S.world.slot=i;TIMECARD=true}}
  else for(let i=0;i<+a.slice(1);i++)passTime()},{once:1});
