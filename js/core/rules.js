/* ============ RULES ============
   The words story files can use after "!" (effects) and after "if" (conditions).

   To add one, write a defEffect or defCond line (here for the basics, in another file for a
   whole system: js/core/world.js is the model). Nothing else in the engine needs to change.
   tools/check_story.py reads the name and the kind straight from these def lines, so keep each
   def on one line starting with defEffect(' or defCond('. The kind says what the argument is,
   and so how the checker checks it:

   effect kinds     flags      FLAG, FLAG ...   switched on (g:FLAG = a village flag, kept between chapters)
                    unflags    FLAG, FLAG ...   switched off
                    place      a place id
                    evidence   evidence ids
                    statement  an id for the line above, saved as a statement
                    mixup      RIGHT / HEARD   two words
                    text       anything
                    amount     +N, -N or =N
                    who_amount WHO +N or WHO -N   (WHO = a key from the cast)
                    item       +NAME or -NAME
   condition kinds  place (@PLACE)   bool   number   slot (a time of day)   gflag   who   item        */

const EFFECTS={},CONDS={};
// fn(arg, x): x.replay = you have passed this beat before in this sitting (don't announce it twice).
// opt.once: this effect adds up (money, friendship, an item), so each beat pays it out only once, ever
//           (rewinds, Back and replaying a chapter can't farm it). End the effect with "each time" to repeat it.
function defEffect(name,kind,fn,opt){EFFECTS[name]=Object.assign({kind,fn},opt)}
// name is a bare word ("money"), a prefix ending in ":" ("rel:" for rel:sujin), or "@" for places.
// fn(rest) returns true/false, or a number that can be compared: money>=500, rel:sujin>=2, day=3.
function defCond(name,kind,fn){CONDS[name]={kind,fn}}

/* ---------- conditions ----------
   COND = terms joined with &.  A term is  [!]NAME  or  [!]NAME>=N  (also <= > < =).
   A NAME nobody defined is a plain chapter flag, set with "! set NAME". */
function condValue(t){
  if(t[0]==='@')return CONDS['@'].fn(t.slice(1));
  const i=t.indexOf(':');
  if(i>0){const c=CONDS[t.slice(0,i+1)];if(c)return c.fn(t.slice(i+1))}
  return CONDS[t]?CONDS[t].fn():S.F[t];
}
const CMP={'>=':(a,b)=>a>=b,'<=':(a,b)=>a<=b,'>':(a,b)=>a>b,'<':(a,b)=>a<b,'=':(a,b)=>a===b};
function cond(c){if(!c)return true;return c.split('&').every(t=>{t=t.trim();
  const neg=t[0]==='!';if(neg)t=t.slice(1);
  const m=t.match(/^(.+?)(>=|<=|>|<|=)(-?\d+)$/);
  const ok=m?CMP[m[2]](+condValue(m[1])||0,+m[3]):!!condValue(t);
  return neg?!ok:ok})}
// a jump target can be "COND ? A : B"
function tgt(t){const m=String(t).match(/^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$/);return m?(cond(m[1])?m[2]:m[3]):String(t).trim()}

defCond('@','place',p=>S.loc===p);
defCond('allSolved','bool',()=>caseReadyNow());

/* ---------- effects ----------
   runFx(list, {replay, key}): key names where the effects come from (a beat, a choice, a phone thread),
   so "once" effects know they have already happened there. No key = they always run. */
function runFx(list,x){x=x||{};(list||[]).forEach((e,i)=>{
  if(e.c&&!cond(e.c))return;
  const d=EFFECTS[e.k];if(!d){console.warn('unknown effect',e.k,e.a);return}
  let a=e.a;
  if(d.once){const m=a.match(/^(.*?)\s+each time$/);   // "! money -1500 each time": a fare, a price: it repeats
    if(m)a=m[1];else if(x.key){const k=S.ch+':'+x.key+':'+i;if(S.world.did[k])return;S.world.did[k]=1}}
  d.fn(a,x)})}
const eachOf=(a,fn)=>a.split(',').forEach(v=>{v=v.trim();if(v)fn(v)});

defEffect('set','flags',a=>eachOf(a,f=>{if(f.startsWith('g:'))S.world.g[f.slice(2)]=1;else S.F[f]=1}));
defEffect('unset','unflags',a=>eachOf(a,f=>{if(f.startsWith('g:'))delete S.world.g[f.slice(2)];else delete S.F[f]}));
defEffect('place','place',a=>{S.loc=a});
defEffect('led','text',a=>{S.F.led=a});
defEffect('toast','text',(a,x)=>{if(!x.replay)toast(esc(a),5000)});
defEffect('learn','text',()=>{}); // from before the notebook was yours: harmless, does nothing
defEffect('mixup','mixup',(a,x)=>{const [r,h]=a.split('/').map(v=>v.trim());const k=r+'/'+h;
  if(!x.replay){S.mx[k]=(S.mx[k]||0)+1;noteUsed('{'+r+'}',false);toast(`Mix-up saved to your notebook: <b>${esc(r)}</b> / <b>${esc(h)}</b>`,4000)}});
defEffect('statement','statement',(a,x)=>{if(!S.F['st_'+a]){S.F['st_'+a]=1;if(!x.replay)toast('Statement saved to your case board.',2600)}});
defEffect('have','evidence',a=>eachOf(a,v=>{S.F['ev_'+v]=1})); // evidence you already carry, no announcement
defEffect('give','evidence',(a,x)=>eachOf(a,v=>{if(!S.F['ev_'+v]){S.F['ev_'+v]=1;const ev=ST.evidence[v];if(ev&&!x.replay)toast(`${iconSVG(ev.icon)} Evidence: <b>${ko(ev.label,false,false)}</b>`,3500)}}));
