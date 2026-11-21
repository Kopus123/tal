/* ============ VILLAGERS ============
   People who live in the village on free days: where they are depends on the time of day,
   and talking to them day after day builds friendship, which opens new conversations.

   Each person has a file in story/people/ (listed under "=== people" in world.story):

     === person sujin
     at morning madang 30 66       where they stand (place, X% Y%) at that time of day; no line = not around
     greet sj_hi                   the first time you talk to them each day (friendship +1)
     chat 0 sj_weather [if COND]   small talk, open from friendship level 0 (levels: 0 to 4)
     story 1 sj_workshop [if COND] something personal, told once, when you reach that level
     ask 할머니 sj_ask_gm [if COND] a topic you can bring up, once you've met the word
     bye sj_bye                    when they have nothing new to say today

   The scenes are ordinary scenes in the same file, so everything a story scene can do works here too.
   Which chat comes up is not random: the one using the most words you're still shaky on goes first.
   That is how old words come back without the game ever saying "review".

   Village events ("=== event" in the free-days chapter file) happen at a place and time whether you
   are there or not. If you are, you see them. If you aren't, someone tells you about it later.   */

const REL_STEPS=[3,7,12,18];                      // friendship points needed for levels 1 to 4
let PEOPLE={},PNODES={},PSTART=new Set();          // id -> person;  every scene from the people files;  scenes a talk can start
const relLevel=who=>REL_STEPS.filter(n=>(S.world.rel[who]||0)>=n).length;
function addRel(who,n){const before=relLevel(who);S.world.rel[who]=Math.max(0,(S.world.rel[who]||0)+n);
  if(relLevel(who)>before)toast(`You and <b>${esc((ST.cast[who]||{}).n||who)}</b> are getting closer. ${'♥'.repeat(relLevel(who))}`,4500)}
function indexPeople(){PSTART=new Set();Object.values(PEOPLE).forEach(p=>[...p.chat,...p.story,...p.ask].forEach(x=>PSTART.add(x.scene)))}
// who is at this place right now (only on free days, when the clock is running)
function peopleHere(){if(!ST||!ST.free||S.world.frozen)return[];
  return Object.values(PEOPLE).filter(p=>{const a=p.at[slotName()];return a&&a.place===S.loc})}
// words in a scene that you have met but don't know yet: the more of them, the sooner that chat comes up
function weakWords(scene){const ids=new Set();
  Object.values(PNODES).forEach(n=>{if((n.id===scene||n.id.startsWith(scene+'.'))&&n.ko)idsIn(n.ko).forEach(id=>ids.add(id))});
  return [...ids].filter(id=>W[id]&&!W[id].g&&S.m[id]&&knowLevel(id)<2).length}
// 은 after a final consonant, 는 after a vowel: "할머니는?" = "what about grandma?"
const topicOf=w=>{const c=w.charCodeAt(w.length-1)-0xAC00;return `{${w}}{${c>=0&&c<11172&&c%28?'은':'는'}|은/는}?`};
function talkTo(id){
  const p=PEOPLE[id];if(!p||busy)return;sfx('tap');revealHeard();
  const day=S.world.day,lv=relLevel(id),seen=S.world.seen,ok=x=>x.lv<=lv&&cond(x.c);
  if(S.world.met[id]!==day){S.world.met[id]=day;addRel(id,1);const g=p.greet[(day+id.length)%Math.max(1,p.greet.length)];save();go(g);return}
  const told=S.world.gossip[id]||[];if(told.length){const sc=told.shift();save();go(sc);return}   // someone missed something: they tell you first
  const job=jobOn(),js=job&&job.ask[id];
  const st=p.story.find(x=>ok(x)&&!seen[x.scene]);if(st&&!js){go(st.scene);return}
  const pool=p.chat.filter(x=>ok(x)&&seen[x.scene]!==day)
    .sort((a,b)=>weakWords(b.scene)-weakWords(a.scene)||(seen[a.scene]||0)-(seen[b.scene]||0));   // shaky words first, then the one heard longest ago
  const asks=p.ask.filter(x=>cond(x.c)&&S.w[x.word]&&seen[x.scene]!==day);
  if(!asks.length&&!js){go(pool.length?pool[0].scene:p.bye);return}
  // the talk menu: small talk, or bring something up
  const key='_talk_'+id;
  ST.nodes[key]={id:key,who:'narr',en:`What do you want to talk to ${(ST.cast[id]||{}).n||id} about?`,
    ch:[...(js?[{en:'About the job: '+job.en,go:js}]:[]),...(st?[{en:'Just chat',go:st.scene}]:pool.length?[{en:'Just chat',go:pool[0].scene}]:[]),...asks.map(x=>({ko:topicOf(x.word),go:x.scene,lang:'ko'})),{en:'Leave it for now',go:p.bye}]};
  go(key);
}
/* ---------- events ---------- */
const evKey=e=>e.id+'@'+S.world.day;
const eventsNow=()=>!ST||!ST.free||S.world.frozen?[]:(ST.events||[]).filter(e=>e.slot===slotName()&&cond(e.when)&&!S.world.evs[evKey(e)]);
// arriving somewhere (or being there when the time comes): an event here plays, once
function checkEvents(){if(S.node)return false;const e=eventsNow().find(e=>e.place===S.loc);
  if(e){S.world.evs[evKey(e)]='seen';go(e.scene);return true}
  const n=ENC_OFF?null:encountersToday().find(n=>n.slot===slotName()&&n.place===S.loc&&!S.world.evs['enc:'+n.id+'@'+S.world.day]);
  if(!n)return false;S.world.evs['enc:'+n.id+'@'+S.world.day]='seen';go(n.scene);return true}
/* ---------- encounters: little things that happen to you around the village ----------
   === encounter ID / at SLOT PLACE (one or more choices) / scene SCENE / when COND.
   Each day 2 or 3 of them are picked (never one you saw yesterday), each at one of its "at"s.
   Walk in at that time and it plays. Miss it and nothing happens: there'll be others. */
let ENC_OFF=false;   // the scripted tests turn them off (they'd interrupt a planned route); the random bot leaves them on
function dayHash(s){let a=[...s].reduce((a,c)=>Math.imul(a^c.charCodeAt(0),16777619)>>>0,2166136261);a^=a>>>16;a=Math.imul(a,0x45d9f3b)>>>0;return(a^a>>>16)>>>0}
function encountersToday(){if(!ST||!ST.free||S.world.frozen||!ST.encounters||!ST.encounters.length)return[];
  const d=S.world.day,seenYesterday=id=>!!S.world.evs['enc:'+id+'@'+(d-1)];
  const pool=ST.encounters.filter(n=>n.at.length&&cond(n.when)&&!seenYesterday(n.id)).sort((a,b)=>dayHash(d+'/'+a.id)-dayHash(d+'/'+b.id));
  const picked=[],used=new Set();
  for(const n of pool){if(picked.length>=2+dayHash('n'+d)%2)break;
    const at=n.at[dayHash(d+'@'+n.id)%n.at.length],k=at.slot+' '+at.place;if(used.has(k))continue;used.add(k);
    picked.push({id:n.id,scene:n.scene,slot:at.slot,place:at.place})}
  return picked}
// time is about to move on: anything due now that you didn't see becomes something you hear about
function missEvents(){eventsNow().forEach(e=>{S.world.evs[evKey(e)]='missed';if(e.missed){const [who,sc]=e.missed;(S.world.gossip[who]=S.world.gossip[who]||[]).push(sc)}})}
defEffect('chapter','chapter',a=>{S.F.goChapter=a.trim()});   // when this scene ends, carry on in another chapter file
