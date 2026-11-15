/* ============ VILLAGERS ============
   People who live in the village on free days: where they are depends on the time of day,
   and talking to them day after day builds friendship, which opens new conversations.

   Each person has a file in story/people/ (listed under "=== people" in world.story):

     === person sujin
     at morning madang 30 66       where they stand (place, X% Y%) at that time of day; no line = not around
     greet sj_hi                   the first time you talk to them each day (friendship +1)
     chat 0 sj_weather             small talk, open from friendship level 0 (levels: 0 to 4)
     story 1 sj_workshop           something personal, told once, when you reach that level
     bye sj_bye                    when they have nothing new to say today

   The scenes are ordinary scenes in the same file, so everything a story scene can do works here too.
   Which chat comes up is not random: the one using the most words you're still shaky on goes first.
   That is how old words come back without the game ever saying "review".                            */

const REL_STEPS=[3,7,12,18];                      // friendship points needed for levels 1 to 4
let PEOPLE={},PNODES={};                           // id -> person;  every scene from the people files
const relLevel=who=>REL_STEPS.filter(n=>(S.world.rel[who]||0)>=n).length;
function addRel(who,n){const before=relLevel(who);S.world.rel[who]=Math.max(0,(S.world.rel[who]||0)+n);
  if(relLevel(who)>before)toast(`You and <b>${esc((ST.cast[who]||{}).n||who)}</b> are getting closer. ${'♥'.repeat(relLevel(who))}`,4500)}
// who is at this place right now (only on free days, when the clock is running)
function peopleHere(){if(!ST||!ST.free||S.world.frozen)return[];
  return Object.values(PEOPLE).filter(p=>{const a=p.at[slotName()];return a&&a.place===S.loc})}
// words in a scene that you have met but don't know yet: the more of them, the sooner that chat comes up
function weakWords(scene){const ids=new Set();
  Object.values(PNODES).forEach(n=>{if((n.id===scene||n.id.startsWith(scene+'.'))&&n.ko)idsIn(n.ko).forEach(id=>ids.add(id))});
  return [...ids].filter(id=>W[id]&&!W[id].g&&S.m[id]&&knowLevel(id)<2).length}
function talkTo(id){
  const p=PEOPLE[id];if(!p||busy)return;sfx('tap');revealHeard();
  const day=S.world.day,lv=relLevel(id),seen=S.world.seen;let scene;
  if(S.world.met[id]!==day){S.world.met[id]=day;addRel(id,1);scene=p.greet[(day+id.length)%Math.max(1,p.greet.length)]}
  else{
    const st=p.story.find(x=>x.lv<=lv&&!seen[x.scene]);
    const pool=p.chat.filter(x=>x.lv<=lv&&seen[x.scene]!==day)
      .sort((a,b)=>weakWords(b.scene)-weakWords(a.scene)||(seen[a.scene]||0)-(seen[b.scene]||0));   // shaky words first, then the one you heard longest ago
    scene=st?st.scene:pool.length?pool[0].scene:p.bye;
  }
  if(!scene||!ST.nodes[scene]){toast('They have nothing to say right now.');return}
  seen[scene]=day;save();go(scene);
}
defEffect('chapter','chapter',a=>{S.F.goChapter=a.trim()});   // when this scene ends, carry on in another chapter file
