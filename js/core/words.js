/* ============ WORDS ============
   Tappable {words}: how they are colored, tracked and matched. */

/* ---------- tokens & words ---------- */
// Word colors come from YOUR notebook, not from the game:
//   new   = first time you've run into it     seen  = met before, no note yet
//   guess = you wrote a meaning, not sure     sure  = you ticked "I'm sure"
const TOK=/\{([^}|]+)(?:\|([^}]+))?\}/g;
const plain=s=>String(s).replace(TOK,'$1');
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const idsIn=s=>[...String(s).matchAll(TOK)].map(m=>m[2]||m[1]);
// Hangul -> jamo, so 봣어요 vs 봤어요 counts as one small slip, not a whole wrong syllable
function jamo(s){const out=[];for(const ch of String(s)){const c=ch.charCodeAt(0)-0xAC00;
  if(c>=0&&c<11172){out.push('L'+Math.floor(c/588),'V'+Math.floor(c%588/28));if(c%28)out.push('T'+c%28)}else out.push(ch)}return out}
function lev(a,b){const d=Array.from({length:a.length+1},(_, i)=>[i]);for(let j=1;j<=b.length;j++)d[0][j]=j;
  for(let i=1;i<=a.length;i++)for(let j=1;j<=b.length;j++)d[i][j]=Math.min(d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+(a[i-1]===b[j-1]?0:1));return d[a.length][b.length]}
const jamoDist=(a,b)=>lev(jamo(a),jamo(b));
// "sure" = you checked your guess and it was right (or ticked it yourself, for a word with no meaning to check against)
const isSure=r=>!!(r&&(r.right||r.sure));
function wrec(id){return S.w[id]||(S.w[id]={ctx:[],note:''})}
/* ---------- word mastery (quiet: nothing shows it yet; later phases read it) ----------
   S.m[word] = {s: times seen in a line, u: times you used it right, x: times you used it wrong, t: day last seen} */
const today=()=>Math.floor(Date.now()/864e5);
const mast=id=>S.m[id]||(S.m[id]={s:0,u:0,x:0,t:0});
function noteSeen(str){idsIn(str).forEach(id=>{if(!W[id])return;const m=mast(id);m.s++;m.t=today()})}
function noteUsed(str,ok){idsIn(str).forEach(id=>{if(!W[id])return;const m=mast(id);if(ok){m.u++;m.k=(m.k||0)+1}else{m.x++;m.k=0}m.t=today()})}
/* ---------- hint fading ----------
   How much help a word still needs: 0 = all of it, 1 = fading, 2 = you know it.
   m.k counts right uses in a row; one slip sets it back to 0 and the hints return.
   A word you marked "sure" and have met often fades a little even if you never had to use it. */
function knowLevel(id){if(!S.set.fade)return 0;const m=S.m[id];if(!m)return 0;const k=m.k||0;
  if(k>=4)return 2;if(k>=2)return 1;const r=S.w[id];return r&&isSure(r)&&m.s>=6&&!m.x?1:0}
// is every real word in this line one you know? (grammar pieces don't count)
function lineKnown(str){const ids=idsIn(str).filter(id=>W[id]&&!W[id].g);return ids.length>0&&ids.every(id=>knowLevel(id)===2)}
// does this answer play out and then rewind you (a wrong answer)?
function leadsToRewind(t){let id=t,n=0;while(id&&n++<40){const nd=ST.nodes[tgt(id)];if(!nd)return false;if(nd.rewind)return true;
  if(nd.ch||nd.ans||nd.shows||nd.type)return false;id=nd.next}return false}
function see(id,line){if(!W[id])return;const r=wrec(id);if(!r.ctx.includes(line)){r.ctx.push(line);if(r.ctx.length>6)r.ctx.shift();r.n=(r.n||0)+1}}
function status(id){const d=W[id];if(!d)return'seen';if(d.g)return'gram';const r=S.w[id];if(!r)return'new';
  if(r.note&&r.note.trim())return isSure(r)?'sure':'guess';return (r.n||0)<=1?'new':'seen'}
function ko(str,tap=true,mark=true){
  let out=esc(str).replace(TOK,(m,surf,id)=>{id=id||surf;if(mark)see(id,str);
    return tap?`<button class="w ${status(id)}" data-w="${id}">${surf}</button>`:surf});
  if(tap&&NAMERX)out=out.split(/(<[^>]+>)/).map(p=>p.startsWith('<')?p:p.replace(NAMERX,m=>`<button class="w name" data-name="${m}">${m}</button>`)).join('');
  return out.replace(/\n/g,'<br>');
}
// names and little sounds (수진, 아이고...) aren't words to learn, but you can still tap them
let NAMERX=null;
function buildNames(){const n=WORLD.names||{},rx=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  const by=k=>Object.keys(n).filter(x=>n[x].kind===k).sort((a,b)=>b.length-a.length).map(rx);
  const parts=[];if(by('name').length)parts.push(`(?:${by('name').join('|')})`);if(by('sound').length)parts.push(`(?:${by('sound').join('|')})(?![가-힣])`);
  NAMERX=parts.length?new RegExp(`(?<![가-힣])(?:${parts.join('|')})`,'g'):null}
const meaningOf=id=>{const k=String(id).split('/')[0];return(WORLD.meanings&&WORLD.meanings[k])||''};
function learn(){} // kept so old story effects ("learn X") are harmless: you decide what you know now
// A pattern page opens once you've met enough of its words: the ones under "when", or else the right-hand
// side of its pairs. S.pat remembers which pages are open.
const patMet=p=>(p.when||p.pairs.map(x=>x[1])).filter(w=>S.w[w]).length;
function checkPattern(){const fresh=ST.patterns.filter(p=>!S.pat[p.id]&&patMet(p)>=p.need);if(!fresh.length)return;
  fresh.forEach(p=>S.pat[p.id]=1);
  toast(fresh.length>1?`${fresh.length} patterns spotted. They're in your notebook's Patterns tab.`:`Pattern spotted: <b>${esc(fresh[0].title)}</b>. It's in your notebook's Patterns tab.`,4500)}
