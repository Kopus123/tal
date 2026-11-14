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

     if money>=500    if day>=3    if time:evening    if rel:sujin>=2    if has:radio    if g:metKid   */

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
defEffect('rel','who_amount',a=>{const [w,n]=a.trim().split(/\s+/),am=amount(n);if(w&&am)S.world.rel[w]=bump(S.world.rel[w]||0,am)},{once:1});
defEffect('item','item',a=>{const m=a.trim().match(/^([+-]?)(\S+)$/);if(!m)return;
  const n=Math.max(0,(S.world.inv[m[2]]||0)+(m[1]==='-'?-1:1));if(n)S.world.inv[m[2]]=n;else delete S.world.inv[m[2]]},{once:1});
