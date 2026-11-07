/* ============ CHARACTER PORTRAITS ============
   Each cast member in the story has a "look" (5th column of === cast):
     hair=bun|long|short|grandma   hc=#hair   skin=#skin   top=#clothes
     wear=plain|hanbok|apron|blazer|cardigan   extra=glasses,flower,wrinkles,stubble
   Lines can set an expression:   sujin[worried]: ...
   Expressions: neutral happy worried surprised sad                                    */

const PK='#2a231d';
function parseLook(s){const o={hair:'short',hc:'#2a1d18',skin:'#e6c3a0',top:'#7fa89a',wear:'plain',extra:''};
  String(s||'').split(/\s+/).forEach(kv=>{const [k,v]=kv.split('=');if(k&&v)o[k]=v});o.extra=o.extra.split(',');return o}

function portrait(lookStr,expr='neutral'){
  const L=parseLook(lookStr),x=L.extra,E=expr||'neutral';
  const sw=`stroke="${PK}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"`;
  let s='';
  // back hair
  if(L.hair==='long')s+=`<path d="M27,46 Q24,14 50,14 Q76,14 73,46 L77,80 Q68,74 66,48 L34,48 Q32,74 23,80Z" fill="${L.hc}" ${sw}/>`;
  if(L.hair==='bun'||L.hair==='grandma')s+=`<circle cx="50" cy="13" r="9" fill="${L.hc}" ${sw}/>`;
  // shoulders + clothes
  s+=`<path d="M8,104 Q10,74 50,70 Q90,74 92,104Z" fill="${L.top}" ${sw}/>`;
  if(L.wear==='hanbok')s+=`<path d="M38,71 L50,90 L62,71" fill="#f6f0e0" ${sw}/><path d="M50,90 L44,104 M50,90 L58,102" stroke="#b5412d" stroke-width="3" stroke-linecap="round"/>`;
  if(L.wear==='apron')s+=`<path d="M34,78 L66,78 L70,104 L30,104Z" fill="#f4f1ea" ${sw}/><path d="M34,78 L40,70 M66,78 L60,70" ${sw}/>`;
  if(L.wear==='blazer')s+=`<path d="M40,71 L50,96 L60,71" fill="#f6f0e0" ${sw}/><path d="M50,96 L50,104" ${sw}/><rect x="56" y="84" width="9" height="12" rx="1.5" fill="#f6f0e0" ${sw}/>`;
  if(L.wear==='cardigan')s+=`<path d="M42,71 L50,104 L58,71" fill="#f4f1ea" ${sw}/><circle cx="47" cy="86" r="1.4" fill="${PK}"/><circle cx="48.5" cy="95" r="1.4" fill="${PK}"/>`;
  // neck, ears, head
  s+=`<path d="M43,58 L43,72 Q50,76 57,72 L57,58Z" fill="${L.skin}" ${sw}/>`;
  s+=`<ellipse cx="29" cy="47" rx="3.5" ry="5" fill="${L.skin}" ${sw}/><ellipse cx="71" cy="47" rx="3.5" ry="5" fill="${L.skin}" ${sw}/>`;
  s+=`<ellipse cx="50" cy="44" rx="21" ry="24" fill="${L.skin}" ${sw}/>`;
  // front hair
  const hairFront={
    short:`<path d="M28,42 Q27,17 50,17 Q73,17 72,42 Q70,30 62,27 Q52,33 40,27 Q31,30 28,42Z" fill="${L.hc}" ${sw}/>`,
    long:`<path d="M28,46 Q27,16 50,16 Q73,16 72,46 Q66,28 50,27 Q34,28 28,46Z" fill="${L.hc}" ${sw}/>`,
    bun:`<path d="M28,42 Q28,18 50,18 Q72,18 72,42 Q66,27 50,26 Q34,27 28,42Z" fill="${L.hc}" ${sw}/>`,
    grandma:`<path d="M28,40 Q27,18 50,18 Q73,18 72,40 Q68,26 58,27 Q54,23 50,27 Q45,23 41,27 Q31,27 28,40Z" fill="${L.hc}" ${sw}/><path d="M36,24 q3,-3 6,0 M47,21 q3,-3 6,0 M58,24 q3,-3 6,0" stroke="#b9b3aa" stroke-width="1.6" fill="none"/>`
  };
  s+=hairFront[L.hair]||hairFront.short;
  if(x.includes('flower'))s+=`<circle cx="68" cy="27" r="4.5" fill="#e9a3b4" ${sw}/><circle cx="68" cy="27" r="1.6" fill="#d9a43d"/>`;
  // brows
  const brows={neutral:'M36,37 q5,-2.5 10,0 M54,37 q5,-2.5 10,0',happy:'M36,35 q5,-3 10,0 M54,35 q5,-3 10,0',
    worried:'M36,39 L46,33 M54,33 L64,39',surprised:'M36,32 q5,-4 10,0 M54,32 q5,-4 10,0',sad:'M37,38 q5,-1 9,-4 M54,34 q4,3 9,4'};
  s+=`<path d="${brows[E]||brows.neutral}" fill="none" stroke="${PK}" stroke-width="2.6" stroke-linecap="round"/>`;
  // eyes
  if(E==='happy')s+=`<path d="M38,46 q3.5,-4.5 7,0 M55,46 q3.5,-4.5 7,0" fill="none" stroke="${PK}" stroke-width="2.6" stroke-linecap="round"/>`;
  else if(E==='surprised')s+=`<circle cx="41.5" cy="45" r="3.6" fill="#fff" ${sw}/><circle cx="58.5" cy="45" r="3.6" fill="#fff" ${sw}/><circle cx="41.5" cy="45" r="1.5" fill="${PK}"/><circle cx="58.5" cy="45" r="1.5" fill="${PK}"/>`;
  else if(E==='sad')s+=`<path d="M38,46 q3.5,2 7,0 M55,46 q3.5,2 7,0" fill="none" stroke="${PK}" stroke-width="2.6" stroke-linecap="round"/>`;
  else s+=`<ellipse cx="41.5" cy="45.5" rx="2.3" ry="3" fill="${PK}"/><ellipse cx="58.5" cy="45.5" rx="2.3" ry="3" fill="${PK}"/>`;
  if(x.includes('wrinkles'))s+=`<path d="M33,47 l-3,1.5 M67,47 l3,1.5 M42,60 q-3,2 -5,0 M58,60 q3,2 5,0" stroke="#a07a60" stroke-width="1.4" fill="none" stroke-linecap="round"/>`;
  if(x.includes('glasses'))s+=`<circle cx="41.5" cy="45.5" r="6.5" fill="none" stroke="${PK}" stroke-width="1.8"/><circle cx="58.5" cy="45.5" r="6.5" fill="none" stroke="${PK}" stroke-width="1.8"/><path d="M48,45 h4" stroke="${PK}" stroke-width="1.8"/>`;
  if(x.includes('stubble'))s+=`<path d="M38,60 Q50,70 62,60 Q60,66 50,67 Q40,66 38,60Z" fill="#9a8f86" opacity=".35"/>`;
  // nose
  s+=`<path d="M50,49 q-2,4 0,5" fill="none" stroke="#a07a60" stroke-width="1.8" stroke-linecap="round"/>`;
  // mouth
  const mouth={neutral:`<path d="M45,58 q5,2.5 10,0" fill="none" stroke="${PK}" stroke-width="2.2" stroke-linecap="round"/>`,
    happy:`<path d="M43,56 q7,9 14,0Z" fill="#8a3326" ${sw}/>`,
    worried:`<path d="M44,59 q2,-2 4,0 t4,0 t4,0" fill="none" stroke="${PK}" stroke-width="2.2" stroke-linecap="round"/>`,
    surprised:`<ellipse cx="50" cy="59" rx="3.2" ry="4.2" fill="#8a3326" ${sw}/>`,
    sad:`<path d="M45,60 q5,-4 10,0" fill="none" stroke="${PK}" stroke-width="2.2" stroke-linecap="round"/>`};
  s+=mouth[E]||mouth.neutral;
  if(E==='happy')s+=`<circle cx="36" cy="53" r="3.6" fill="#e07b8a" opacity=".45"/><circle cx="64" cy="53" r="3.6" fill="#e07b8a" opacity=".45"/>`;
  if(E==='worried')s+=`<path d="M70,30 q3,5 0,7 q-3,-2 0,-7Z" fill="#9fc6e0" stroke="${PK}" stroke-width="1.4"/>`;
  if(E==='sad')s+=`<path d="M38,49 q-1.5,4 0,6 q1.5,-2 0,-6Z" fill="#9fc6e0" stroke="${PK}" stroke-width="1.2"/>`;
  return `<svg viewBox="0 0 100 100" aria-hidden="true">${s}</svg>`;
}

// the bus announcer and other voices without a face
function speakerGlyph(){return `<svg viewBox="0 0 100 100" aria-hidden="true"><path d="M26,40 H40 L58,24 V76 L40,60 H26Z" fill="#3b4048" stroke="${PK}" stroke-width="3" stroke-linejoin="round"/><path d="M68,36 q8,14 0,28 M76,28 q14,22 0,44" fill="none" stroke="#d9a43d" stroke-width="4" stroke-linecap="round"/></svg>`}
