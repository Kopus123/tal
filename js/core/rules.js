/* ============ RULES ============
   The words story files can use after "!" (effects) and after "if" (conditions).
   Add a new one with defEffect / defCond: nothing else in the engine needs to change,
   and tools/check_story.py reads the names and kinds from the def lines in js/core/*.js. */

function cond(c){if(!c)return true;return c.split('&').every(t=>{t=t.trim();
  const neg=t.startsWith('!');if(neg)t=t.slice(1);
  let v=t.startsWith('@')?S.loc===t.slice(1):t==='allSolved'?caseReadyNow():!!S.F[t];
  return neg?!v:v})}
function tgt(t){const m=String(t).match(/^(.+?)\s*\?\s*(\S+)\s*:\s*(\S+)$/);return m?(cond(m[1])?m[2]:m[3]):String(t).trim()}
function runFx(list,replay){(list||[]).forEach(e=>{if(e.c&&!cond(e.c))return;const a=e.a;
  if(replay&&e.k==='toast')return;
  if(e.k==='set')a.split(',').forEach(f=>S.F[f.trim()]=1);
  else if(e.k==='unset')a.split(',').forEach(f=>delete S.F[f.trim()]);
  else if(e.k==='place')S.loc=a;
  else if(e.k==='led')S.F.led=a;
  else if(e.k==='toast')toast(esc(a),5000);
  else if(e.k==='mixup'){const [r,h]=a.split('/').map(x=>x.trim());const k=r+'/'+h;
    if(!replay){S.mx[k]=(S.mx[k]||0)+1;noteUsed('{'+r+'}',false);toast(`Mix-up saved to your notebook: <b>${esc(r)}</b> / <b>${esc(h)}</b>`,4000)}}
  else if(e.k==='statement'){if(!S.F['st_'+a]){S.F['st_'+a]=1;if(!replay)toast('Statement saved to your case board.',2600)}}
  else if(e.k==='have')a.split(',').forEach(x=>S.F['ev_'+x.trim()]=1); // evidence you already carry, no announcement
  else if(e.k==='give')a.split(',').forEach(x=>{x=x.trim();if(!S.F['ev_'+x]){S.F['ev_'+x]=1;const ev=ST.evidence[x];if(ev&&!replay)toast(`${iconSVG(ev.icon)} Evidence: <b>${ko(ev.label,false,false)}</b>`,3500)}});
})}
