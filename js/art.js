/* ============ SCENE ART ============
   Every place in the story names one of these with "art NAME".
   Drawings are 400 x 300 SVG. Palette: hanji paper, ink, dancheong green / red / ochre. */

const DEFS=`<defs>
 <pattern id="lat" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="8" fill="#f1e8d2"/><path d="M0 0H8M0 0V8" stroke="#a07a52" stroke-width="1"/></pattern>
 <pattern id="latE" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="8" fill="#f2c27a"/><path d="M0 0H8M0 0V8" stroke="#6b4528" stroke-width="1"/></pattern>
 <pattern id="stone" width="26" height="16" patternUnits="userSpaceOnUse"><rect width="26" height="16" fill="#8d877b"/><ellipse cx="7" cy="5" rx="7" ry="4.5" fill="#a39c8e"/><ellipse cx="20" cy="5.5" rx="6" ry="4" fill="#9a9385"/><ellipse cx="13" cy="12.5" rx="7.5" ry="4" fill="#aaa294"/><ellipse cx="0" cy="12.5" rx="5" ry="3.5" fill="#968f81"/><ellipse cx="26" cy="12.5" rx="5" ry="3.5" fill="#968f81"/></pattern>
 <pattern id="stoneE" width="26" height="16" patternUnits="userSpaceOnUse"><rect width="26" height="16" fill="#2f3140"/><ellipse cx="7" cy="5" rx="7" ry="4.5" fill="#3d4052"/><ellipse cx="20" cy="5.5" rx="6" ry="4" fill="#393b4c"/><ellipse cx="13" cy="12.5" rx="7.5" ry="4" fill="#43465a"/></pattern>
 <pattern id="plank" width="40" height="22" patternUnits="userSpaceOnUse"><rect width="40" height="22" fill="#7a5536"/><path d="M0 21.5H40" stroke="#5e3f27" stroke-width="1"/><path d="M28 0V22" stroke="#6a4930" stroke-width=".8"/></pattern>
 <radialGradient id="glowG"><stop offset="0" stop-color="#ffcf7a" stop-opacity=".75"/><stop offset="1" stop-color="#ffcf7a" stop-opacity="0"/></radialGradient>
 <filter id="blur"><feGaussianBlur stdDeviation="1.4"/></filter>
</defs>`;
const svg=inner=>`<svg class="art" viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice" aria-hidden="true">${DEFS}${inner}</svg>`;

function roof(x,y,w,c='#3b4048',t='#4d545e'){
  const top=y-30;let s=`<path d="M${x-30},${y-3} Q${x-8},${y+8} ${x+16},${y+2} L${x+w-16},${y+2} Q${x+w+8},${y+8} ${x+w+30},${y-3} L${x+w-12},${top} L${x+12},${top} Z" fill="${c}"/>`;
  for(let k=x-4;k<x+w+6;k+=7){const dx=(k-(x+w/2))*.09;s+=`<line x1="${k-dx*.4}" y1="${top+3}" x2="${k+dx}" y2="${y}" stroke="${t}" stroke-width="2.4"/>`}
  s+=`<path d="M${x+4},${top-1} L${x+w-4},${top-1} L${x+w+4},${top-8} L${x+w-6},${top-4} L${x+6},${top-4} L${x-4},${top-8} Z" fill="${c}" stroke="#262a30" stroke-width="1"/>`;
  return s;
}
function hanok(x,y,w,h,eve){
  const n=Math.max(2,Math.round(w/56)),dw=w/n;let s='';
  s+=`<rect x="${x-6}" y="${y+h}" width="${w+12}" height="12" fill="${eve?'#4a4a55':'#9a958b'}"/>`;
  s+=`<rect x="${x}" y="${y}" width="${w}" height="${h-12}" fill="${eve?'#4b3c33':'#ede5d3'}"/>`;
  for(let i=0;i<n;i++)s+=`<rect x="${x+i*dw+6}" y="${y+8}" width="${dw-12}" height="${h-30}" fill="url(#${eve?'latE':'lat'})"/>`;
  s+=`<rect x="${x}" y="${y+h-12}" width="${w}" height="12" fill="${eve?'#5a3b24':'#8a5a34'}"/>`;
  for(let i=0;i<=n;i++)s+=`<rect x="${x+i*dw-3}" y="${y}" width="6" height="${h}" fill="${eve?'#3a2616':'#6b4528'}"/>`;
  s+=`<rect x="${x-8}" y="${y-7}" width="${w+16}" height="9" fill="#3f7f6e"/><rect x="${x-8}" y="${y-7}" width="${w+16}" height="2" fill="#b5412d"/>`;
  for(let k=x;k<x+w;k+=14)s+=`<circle cx="${k}" cy="${y-2}" r="1.7" fill="#e8c35a"/>`;
  return s+roof(x,y-7,w);
}
// A standing figure. (x,y) = feet. Options: top, bot, skin, hair (colors), hanbok, apron, bun, long, s (scale)
function person(x,y,o={}){
  const s=o.s||1,top=o.top||'#7fa89a',bot=o.bot||'#3b4a5a',skin=o.skin||'#e3c09a',hair=o.hair||'#1f1a18';
  const ln='stroke="#2a231d" stroke-width="1" stroke-linejoin="round"';
  let g=`<g transform="translate(${x},${y}) scale(${s})">`;
  g+=`<ellipse cx="0" cy="0" rx="13" ry="2.6" fill="rgba(0,0,0,.18)"/>`;
  if(o.long)g+=`<path d="M-8,-58 Q-10,-46 -8,-40 L8,-40 Q10,-46 8,-58Z" fill="${hair}" ${ln}/>`;
  if(o.hanbok)g+=`<path d="M-14,-1 Q-12,-18 -7,-31 L7,-31 Q12,-18 14,-1 Q0,1 -14,-1Z" fill="${bot}" ${ln}/>`;
  else g+=`<path d="M-7,-23 L-7,-2 L-2,-2 L-1,-16 L1,-16 L2,-2 L7,-2 L7,-23Z" fill="${bot}" ${ln}/><path d="M-8,-2 h6 v2 h-7Z M2,-2 h6 l1,2 h-7Z" fill="#2a231d"/>`;
  g+=`<path d="M-9,-43 Q-11,-32 -8,-${o.hanbok?30:22} L8,-${o.hanbok?30:22} Q11,-32 9,-43 Q0,-46 -9,-43Z" fill="${top}" ${ln}/>`;
  if(o.hanbok)g+=`<path d="M-3,-43 L0,-37 L3,-43" fill="#f6f0e0" ${ln}/><path d="M0,-37 l-2,6 M0,-37 l2,5" stroke="#b5412d" stroke-width="1.6" stroke-linecap="round"/>`;
  if(o.apron)g+=`<path d="M-6,-38 L6,-38 L7,-20 L-7,-20Z" fill="#f4f1ea" ${ln}/>`;
  g+=`<path d="M-9,-42 Q-14,-34 -12,-25" stroke="${top}" stroke-width="4.5" fill="none" stroke-linecap="round"/><path d="M9,-42 Q14,-34 12,-25" stroke="${top}" stroke-width="4.5" fill="none" stroke-linecap="round"/>`;
  g+=`<circle cx="-12" cy="-24" r="2.2" fill="${skin}"/><circle cx="12" cy="-24" r="2.2" fill="${skin}"/>`;
  g+=`<rect x="-2.2" y="-47" width="4.4" height="4" fill="${skin}"/>`;
  g+=`<ellipse cx="0" cy="-52" rx="7" ry="7.8" fill="${skin}" ${ln}/>`;
  g+=`<path d="M-7.3,-52 Q-8,-61 0,-61 Q8,-61 7.3,-52 Q4,-57 0,-56.5 Q-4,-57 -7.3,-52Z" fill="${hair}" ${ln}/>`;
  if(o.bun)g+=`<circle cx="0" cy="-62" r="3.6" fill="${hair}" ${ln}/>`;
  g+=`<circle cx="-2.6" cy="-51.5" r=".9" fill="#2a231d"/><circle cx="2.6" cy="-51.5" r=".9" fill="#2a231d"/>`;
  return g+'</g>';
}
function mask(cx,cy,s,o={}){
  const c=o.c||'#e7d2a7';
  return `<g transform="translate(${cx},${cy}) scale(${s})"><ellipse rx="14" ry="18" fill="${c}" stroke="#7d5c3a" stroke-width="1.2"/>
   <path d="M-11,-9 Q-6,-14 -1,-9 M1,-9 Q6,-14 11,-9" stroke="#2e2218" stroke-width="1.8" fill="none"/>
   <path d="M-9,-3 Q-5,-7 -2,-3 M2,-3 Q5,-7 9,-3" stroke="#2e2218" stroke-width="1.6" fill="none"/>
   <path d="M-9,6 Q0,16 9,6 Q0,10 -9,6Z" fill="#5a2a1d"/>
   <circle cx="-9" cy="3" r="2.6" fill="#c45a45" opacity=".5"/><circle cx="9" cy="3" r="2.6" fill="#c45a45" opacity=".5"/></g>`;
}
function lantern(x,y,c,lit){return `<line x1="${x}" y1="${y-10}" x2="${x}" y2="${y-5}" stroke="#2a2a2a"/>${lit?`<circle cx="${x}" cy="${y+3}" r="16" fill="url(#glowG)"/>`:''}<ellipse cx="${x}" cy="${y+3}" rx="6" ry="8" fill="${c}"/><rect x="${x-3}" y="${y-6}" width="6" height="2" fill="#2a2a2a"/><rect x="${x-3}" y="${y+10}" width="6" height="2" fill="#2a2a2a"/>`}
function lanternString(eve){let s=`<path d="M-10,40 Q100,70 200,48 T410,44" stroke="#2a2a2a" fill="none" stroke-width="1"/>`;const cs=['#c9452f','#3f7f6e','#d9a43d','#4f6ea8'];for(let i=0;i<9;i++){const x=10+i*46;const y=40+Math.sin(i*1.3)*8+14;s+=lantern(x,y,cs[i%4],eve)}return s}
function mountains(c1,c2){return `<path d="M0,150 Q60,90 120,130 T240,110 T400,120 V300 H0Z" fill="${c1}"/><path d="M0,175 Q90,130 170,160 T330,140 T400,150 V300 H0Z" fill="${c2}"/>`}
function pine(x,y,s=1,c='#2f4a3c'){return `<g transform="translate(${x},${y}) scale(${s})"><rect x="-2" y="-6" width="4" height="12" fill="#4a3424"/><path d="M0,-44 L14,-18 L6,-18 L18,-2 L-18,-2 L-6,-18 L-14,-18Z" fill="${c}"/></g>`}

function artMadang(eve){
  let s=`<rect width="400" height="300" fill="${eve?'#1c2238':'#bcd6df'}"/><rect y="90" width="400" height="80" fill="${eve?'#3c3352':'#f2dcc0'}" opacity=".7"/>`;
  s+=mountains(eve?'#2a3047':'#8aa79b',eve?'#232a3d':'#6f8f82');
  s+=hanok(70,128,260,90,eve);
  s+=`<rect y="230" width="400" height="70" fill="${eve?'#3a3446':'#d8c7a3'}"/>`;
  [[342,262,16],[368,268,13],[318,272,11],[386,280,10]].forEach(([x,y,r])=>s+=`<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r*1.05}" fill="#6b3f26"/><ellipse cx="${x-r*.35}" cy="${y-r*.4}" rx="${r*.25}" ry="${r*.35}" fill="#8c5a3a"/><rect x="${x-r*.55}" y="${y-r*1.15}" width="${r*1.1}" height="3" fill="#4d2c19"/>`);
  s+=`<path d="M28,240 Q30,200 22,170 M24,190 Q10,180 4,170 M26,200 Q42,185 50,176" stroke="#4a3424" stroke-width="4" fill="none"/><circle cx="24" cy="160" r="26" fill="${eve?'#26402f':'#5d8a5a'}"/>`;
  for(let i=0;i<7;i++)s+=`<circle cx="${8+i*6.5}" cy="${150+(i%3)*9}" r="3" fill="#e2862e"/>`;
  if(!eve)s+=`<rect x="205" y="204" width="9" height="5" rx="1" fill="#e9a3b4" stroke="#333" stroke-width=".6"/>`;
  s+=`<rect x="0" y="232" width="16" height="68" fill="#5a3b24"/>`;
  s+=person(120,232,{top:'#c7d3cf',bot:'#5b6a7a',bun:1});
  if(eve){
    for(let i=0;i<6;i++)s+=lantern(90+i*44,126,i%2?'#c9452f':'#d9a43d',true);
    s+=person(300,232,{top:'#8a6a9a',bot:'#4a3a52',hanbok:1,bun:1,hair:'#d8d4ce'})+mask(314,206,.45,{c:'#e7d2a7'});
  }
  return svg(s);
}
function artGongbang(){
  let s=`<rect width="400" height="300" fill="url(#plank)"/>`;
  s+=`<rect x="0" y="0" width="400" height="14" fill="#3f7f6e"/><rect y="12" width="400" height="3" fill="#b5412d"/>`;
  const cols=['#e7d2a7','#f1ece0','#d9a07a','#e7d2a7','#c4865c','#efe2c0'];
  let k=0;for(let r=0;r<3;r++)for(let c=0;c<5;c++){const x=80+c*60,y=48+r*52;
    s+=`<circle cx="${x}" cy="${y-24}" r="2" fill="#2a1d12"/>`;
    if(r===1&&c===2){s+=`<ellipse cx="${x}" cy="${y}" rx="15" ry="19" fill="#8a6545" stroke="#c9b48c" stroke-dasharray="3 3" stroke-width="1.2"/>`}
    else s+=mask(x,y,.95,{c:cols[k++%cols.length]});}
  s+=`<rect x="28" y="88" width="40" height="50" fill="#f3ead7" transform="rotate(-4 48 113)"/><rect x="32" y="92" width="32" height="34" fill="#b9a585" transform="rotate(-4 48 113)"/>`;
  s+=`<rect x="330" y="60" width="52" height="64" fill="#f6f0e0"/><rect x="330" y="60" width="52" height="12" fill="#b5412d"/>`;
  for(let i=0;i<4;i++)for(let j=0;j<4;j++)s+=`<rect x="${335+j*12}" y="${78+i*11}" width="8" height="7" fill="#d9cfb8"/>`;
  s+=`<circle cx="363" cy="92" r="7" fill="none" stroke="#b5412d" stroke-width="1.6"/>`;
  s+=`<rect x="0" y="218" width="400" height="82" fill="#4e3421"/><rect x="0" y="214" width="400" height="8" fill="#6b4528"/>`;
  for(let i=0;i<22;i++)s+=`<path d="M${30+i*16},${228+(i%3)*6} q4,-4 8,0" stroke="#d9b98a" stroke-width="1.4" fill="none"/>`;
  for(let i=0;i<5;i++)s+=`<rect x="${150+i*14}" y="232" width="3" height="18" fill="#b8b8b8"/><rect x="${149+i*14}" y="248" width="5" height="10" fill="#6b4528"/>`;
  return svg(s);
}
function artGolmok(){
  let s=`<rect width="400" height="300" fill="#c6dbe0"/>`+mountains('#94ae9f','#7c9a8b');
  s+=`<path d="M0,110 L150,160 L150,300 L0,300Z" fill="url(#stone)"/><path d="M400,110 L250,160 L250,300 L400,300Z" fill="url(#stone)"/>`;
  s+=`<path d="M0,104 L152,156 L152,162 L0,114Z" fill="#3b4048"/><path d="M400,104 L248,156 L248,162 L400,114Z" fill="#3b4048"/>`;
  s+=`<path d="M150,160 L250,160 L250,300 L150,300Z" fill="#cdbb95"/>`;
  s+=`<path d="M178,300 L195,190 L205,190 L222,300Z" fill="#dccca8"/><path d="M195,190 L120,215 L150,232 Z" fill="#dccca8"/><path d="M205,190 L280,215 L250,232Z" fill="#dccca8"/>`;
  s+=lanternString(false);
  s+=person(178,214,{top:'#e9a3b4',bot:'#c9452f',hanbok:1,long:1,s:.95})+person(214,214,{top:'#9fb7d9',bot:'#2d3f66',hanbok:1,s:1});
  return svg(s);
}
function artSan(){
  let s=`<rect width="400" height="300" fill="#cfe0dc"/>`+mountains('#86a596','#5f7f6f');
  s+=`<path d="M160,300 Q200,220 190,170 Q185,150 205,130" stroke="#d6c39b" stroke-width="40" fill="none"/>`;
  for(let i=0;i<9;i++)s+=pine(20+i*45+(i%2)*10,200+(i%3)*30,1+(i%2)*.3);
  s+=`<ellipse cx="310" cy="250" rx="40" ry="18" fill="#7e9c64"/><rect x="230" y="190" width="5" height="40" fill="#6b4528"/><rect x="214" y="188" width="38" height="12" fill="#8a5a34"/>`;
  return svg(s);
}
function artSikdang(){
  let s=`<rect width="400" height="300" fill="#c9a577"/><rect y="0" width="400" height="10" fill="#5a3b24"/>`;
  const menu=[['김밥','3,000'],['떡볶이','4,000'],['라면','4,500'],['비빔밥','8,000']];
  menu.forEach((m,i)=>{const x=20+i*58;s+=`<rect x="${x}" y="30" width="50" height="78" fill="#f2e8d0" stroke="#6b4528" stroke-width="2"/><text x="${x+25}" y="62" text-anchor="middle" font-family="Gowun Batang,serif" font-size="13" fill="#2a231d">${m[0]}</text><text x="${x+25}" y="90" text-anchor="middle" font-family="Gowun Dodum,sans-serif" font-size="10" fill="#7b705f">${m[1]}</text>`});
  s+=`<rect x="270" y="28" width="116" height="92" fill="#a9c9d3" stroke="#5a3b24" stroke-width="5"/><line x1="328" y1="28" x2="328" y2="120" stroke="#5a3b24" stroke-width="3"/>`;
  s+=`<rect x="338" y="58" width="4" height="58" fill="#555"/><circle cx="340" cy="56" r="10" fill="#2f5aa8"/><text x="340" y="60" text-anchor="middle" font-size="8" fill="#fff" font-family="Gowun Dodum,sans-serif">버스</text>`;
  s+=person(200,206,{top:'#7d8a96',bot:'#3a3a3a',apron:1,s:1.25,hair:'#5a5555'});
  s+=`<rect x="0" y="190" width="400" height="24" fill="#6b4528"/><rect x="0" y="214" width="400" height="86" fill="#4e3421"/>`;
  s+=`<ellipse cx="90" cy="186" rx="22" ry="5" fill="#f4f1ea"/><ellipse cx="90" cy="183" rx="14" ry="4" fill="#c9452f"/><rect x="300" y="170" width="10" height="20" fill="#cfd6db"/>`;
  return svg(s);
}
function artJeong(){
  let s=`<rect width="400" height="300" fill="#c9dde3"/>`+mountains('#94ae9f','#7c9a8b');
  s+=`<rect y="200" width="400" height="100" fill="#7c9a5f"/><rect y="236" width="400" height="44" fill="#55595f"/><path d="M0,258 H400" stroke="#e8e0c8" stroke-width="2" stroke-dasharray="18 14"/>`;
  s+=`<rect x="200" y="150" width="140" height="8" fill="#3b4048"/><rect x="206" y="156" width="5" height="80" fill="#3b4048"/><rect x="330" y="156" width="5" height="80" fill="#3b4048"/><rect x="214" y="160" width="112" height="56" fill="#a9c9d3" opacity=".5"/><rect x="220" y="206" width="100" height="6" fill="#6b4528"/>`;
  s+=`<rect x="90" y="120" width="5" height="116" fill="#555"/><rect x="60" y="112" width="70" height="44" fill="#f6f0e0" stroke="#2f5aa8" stroke-width="3"/><circle cx="72" cy="124" r="3" fill="#2f5aa8"/><path d="M72,124 H118" stroke="#2f5aa8" stroke-width="1.5"/>`;
  [84,96,108,118].forEach(x=>s+=`<circle cx="${x}" cy="124" r="2.4" fill="#fff" stroke="#2f5aa8"/>`);
  s+=`<rect x="0" y="150" width="50" height="86" fill="#ede5d3"/>`+roof(4,150,42);
  return svg(s);
}
function artBus(){
  const led=(typeof S!=='undefined'&&S.F.led)||'';
  let s=`<rect width="400" height="300" fill="#2b2f37"/>`;
  s+=`<g><rect x="20" y="70" width="360" height="120" fill="#a9cfd8"/><g class="drift">`;
  for(let k=0;k<2;k++){s+=`<g transform="translate(${k*400},0)"><path d="M20,170 Q120,120 220,150 T420,140 V190 H20Z" fill="#7fa08f"/>${pine(60,182,.8)}${pine(150,184,.9)}${pine(260,182,.7)}${pine(340,186,.85)}<rect x="0" y="180" width="400" height="10" fill="#6f8c5a"/></g>`}
  s+=`</g></g>`;
  s+=`<rect x="20" y="70" width="360" height="120" fill="none" stroke="#1a1d22" stroke-width="6"/><line x1="140" y1="70" x2="140" y2="190" stroke="#1a1d22" stroke-width="6"/><line x1="260" y1="70" x2="260" y2="190" stroke="#1a1d22" stroke-width="6"/>`;
  s+=`<rect x="90" y="14" width="220" height="40" rx="4" fill="#120e0a" stroke="#444" stroke-width="2"/><text x="200" y="42" text-anchor="middle" font-family="Gowun Batang,serif" font-size="20" fill="#ffb347">${String(led).replace(/[<&]/g,'')}</text>`;
  s+=`<rect y="196" width="400" height="104" fill="#3f4652"/>`;
  [[40,210],[160,210],[280,210]].forEach(([x,y])=>s+=`<rect x="${x}" y="${y}" width="80" height="60" rx="10" fill="#2f6f61"/><rect x="${x}" y="${y}" width="80" height="16" rx="6" fill="#3f8b77"/>`);
  s+=`<rect x="0" y="60" width="400" height="5" fill="#9aa"/>`;
  return svg(s);
}
function artMuseum(){
  let s=`<rect width="400" height="300" fill="#e4e6e8"/><rect y="0" width="400" height="40" fill="#cfd3d7"/>`;
  for(let i=0;i<8;i++)s+=`<rect x="${10+i*50}" y="10" width="30" height="6" fill="#fff" opacity=".9"/>`;
  s+=`<rect x="30" y="80" width="130" height="110" fill="#f3f5f7" stroke="#b9c0c6" stroke-width="2"/><rect x="34" y="84" width="122" height="102" fill="#dbe8ee" opacity=".55"/>`;
  s+=mask(95,130,1.6,{c:'#cfa877'});
  s+=`<rect x="30" y="190" width="130" height="50" fill="#9aa3ab"/>`;
  s+=`<rect x="190" y="110" width="40" height="40" fill="#f3f5f7" stroke="#b9c0c6"/>${mask(210,130,.7,{c:'#e7d2a7'})}<rect x="190" y="150" width="40" height="90" fill="#aab2b9"/>`;
  s+=person(264,236,{top:'#2d3f66',bot:'#2a2a2a',long:1,s:1.15});
  s+=`<rect x="220" y="200" width="150" height="50" fill="#5b6370"/><rect x="220" y="196" width="150" height="6" fill="#3c434d"/><rect x="300" y="176" width="34" height="22" fill="#222"/>`;
  s+=`<rect y="250" width="400" height="50" fill="#c3c8cd"/>`;
  return svg(s);
}
function artGateInner(withMask){
  let s=`<rect width="400" height="300" fill="#141a2c"/>`;
  for(let i=0;i<40;i++)s+=`<circle cx="${(i*97)%400}" cy="${(i*53)%120}" r="${(i%3)*.4+.4}" fill="#fff" opacity=".6"/>`;
  s+=mountains('#1f2740','#1a2135');
  s+=`<rect x="0" y="130" width="120" height="170" fill="url(#stoneE)"/><rect x="280" y="130" width="120" height="170" fill="url(#stoneE)"/>`;
  s+=roof(118,118,164,'#23262d','#2f333b');
  s+=`<rect x="122" y="118" width="156" height="10" fill="#2e5f53"/><rect x="128" y="128" width="10" height="150" fill="#3a2616"/><rect x="262" y="128" width="10" height="150" fill="#3a2616"/>`;
  s+=`<rect x="138" y="132" width="61" height="146" fill="#5a3b24"/><rect x="201" y="132" width="61" height="146" fill="#5a3b24"/>`;
  for(let i=0;i<4;i++){s+=`<line x1="140" y1="${150+i*34}" x2="197" y2="${150+i*34}" stroke="#3a2616" stroke-width="3"/><line x1="203" y1="${150+i*34}" x2="260" y2="${150+i*34}" stroke="#3a2616" stroke-width="3"/>`}
  s+=`<circle cx="195" cy="206" r="3" fill="#c9a04a"/><circle cx="205" cy="206" r="3" fill="#c9a04a"/>`;
  s+=lantern(100,150,'#c9452f',true)+lantern(300,150,'#d9a43d',true);
  s+=`<rect y="278" width="400" height="22" fill="#2a2636"/>`;
  if(withMask){s+=`<circle cx="200" cy="175" r="40" fill="url(#glowG)" opacity=".6"/><path d="M186,152 Q200,140 214,152" stroke="#2a1d12" stroke-width="1.5" fill="none"/>`+mask(200,176,1.25,{c:'#e7d2a7'})+`<rect x="208" y="196" width="18" height="12" fill="#f6f0e0" transform="rotate(8 217 202)"/>`;
    s+=person(80,282,{top:'#c7d3cf',bot:'#3b4a5a',bun:1,s:1.1})}
  return DEFS+s;
}
function artGate(){return `<svg class="art" viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice" aria-hidden="true">${artGateInner(true)}</svg>`}
function photoArt(){
  let s=`<rect width="300" height="220" fill="#c9dde3"/><rect y="150" width="300" height="70" fill="#55595f"/><rect x="170" y="70" width="120" height="7" fill="#3b4048"/><rect x="176" y="76" width="4" height="80" fill="#3b4048"/><rect x="282" y="76" width="4" height="80" fill="#3b4048"/>`;
  s+=`<g filter="url(#blur)">${person(232,160,{top:'#8c7f6e',bot:'#4a4440',bun:1,hair:'#d8d4ce',s:.9})}<rect x="240" y="122" width="16" height="12" rx="3" fill="#b5412d"/></g>`;
  s+=person(95,232,{top:'#e9a3b4',bot:'#c9452f',hanbok:1,long:1,s:2.4})+person(160,232,{top:'#9fb7d9',bot:'#2d3f66',hanbok:1,s:2.5});
  return DEFS+s;
}

/* Village map, 400 x 520, painted on hanji. Pin positions live in story/world.story (=== map). */
function artMap(){
  let s=`<rect width="400" height="520" fill="#efe5cc"/>`;
  for(let i=0;i<70;i++){const x=(i*137)%400,y=(i*89)%520,l=6+(i%5)*3;s+=`<path d="M${x},${y} q${l/2},${(i%3)-1} ${l},0" stroke="#d8c9a6" stroke-width=".8" fill="none" opacity=".7"/>`}
  // mountains (ink wash, layered)
  const peaks=[[-20,175,90,40,'#8fa494'],[40,160,170,60,'#7d958a'],[120,150,250,30,'#94a89a'],[220,140,330,50,'#8a9f92'],[310,150,430,70,'#9aae9f'],[-10,190,140,105,'#6f897c'],[150,185,300,110,'#7b9487']];
  peaks.forEach(([x1,y,x2,top,c])=>{const mx=(x1+x2)/2;s+=`<path d="M${x1},${y} Q${mx-30},${top+20} ${mx},${top} Q${mx+30},${top+20} ${x2},${y}Z" fill="${c}" opacity=".55"/>`});
  for(let i=0;i<26;i++){const x=10+(i*53)%380,y=150+((i*31)%60);s+=`<path d="M${x},${y} l4,-11 l4,11Z" fill="#3f5a4b" opacity=".75"/>`}
  // rice paddies
  for(let r=0;r<3;r++)for(let c=0;c<4;c++)s+=`<rect x="${20+c*34}" y="${420+r*26}" width="30" height="22" rx="3" fill="#b9c98f" opacity=".7" stroke="#8fa36a" stroke-width=".8"/>`;
  // river
  s+=`<path d="M262,-10 C248,80 304,120 292,195 S326,300 410,336" stroke="#9cbfcf" stroke-width="30" fill="none" stroke-linecap="round"/>`;
  s+=`<path d="M262,-10 C248,80 304,120 292,195 S326,300 410,336" stroke="#c5dce5" stroke-width="10" fill="none" stroke-linecap="round" opacity=".8"/>`;
  for(let i=0;i<8;i++)s+=`<path d="M${270+i*14},${40+i*40} q5,-3 10,0" stroke="#e8f2f5" stroke-width="1.4" fill="none"/>`;
  // roads
  const road=(d,dash)=>`<path d="${d}" stroke="#b08b5e" stroke-width="3" fill="none" stroke-linecap="round" ${dash?`stroke-dasharray="${dash}"`:''}/>`;
  s+=road('M160,262 Q150,290 136,312')+road('M160,262 Q182,240 200,231')+road('M136,312 Q100,280 96,230 Q90,180 64,142','2 6')+road('M136,312 Q170,340 204,364')+road('M204,364 Q224,378 244,386');
  s+=road('M244,386 C300,370 306,280 298,214 S330,172 344,160','8 6');
  // bridge
  s+=`<g transform="translate(298,214) rotate(-12)"><rect x="-24" y="-6" width="48" height="12" rx="2" fill="#8a5a34" stroke="#5a3b24" stroke-width="1.5"/><path d="M-20,-6 v12 M-10,-6 v12 M0,-6 v12 M10,-6 v12 M20,-6 v12" stroke="#5a3b24" stroke-width="1"/></g>`;
  // houses
  const house=(x,y,w=22,c='#3b4048')=>`<rect x="${x-w/2+3}" y="${y-2}" width="${w-6}" height="9" fill="#f4eedf" stroke="#6b4528" stroke-width="1"/><path d="M${x-w/2-3},${y} Q${x},${y-5} ${x+w/2+3},${y} L${x+w/2-2},${y-8} L${x-w/2+2},${y-8}Z" fill="${c}"/>`;
  [[118,240],[128,272],[100,300],[176,300],[150,340],[182,332],[118,350],[228,268],[214,300],[238,330],[90,262],[168,385]].forEach(([x,y])=>s+=house(x,y,18,'#5a6068'));
  s+=house(160,256,34)+house(200,226,24,'#4a4f57');
  s+=house(204,360,22,'#6b4528')+`<rect x="236" y="378" width="16" height="10" fill="#4f6ea8" rx="2"/>`;
  s+=`<rect x="328" y="146" width="34" height="18" fill="#dfe3e6" stroke="#6a6f7d" stroke-width="1.5"/><path d="M324,147 L345,136 L366,147Z" fill="#c9ced3" stroke="#6a6f7d" stroke-width="1.5"/>`;
  // stone wall around the guesthouse
  s+=`<rect x="138" y="240" width="76" height="34" rx="6" fill="none" stroke="#8d877b" stroke-width="2" stroke-dasharray="3 2"/>`;
  // compass + title seal
  s+=`<g transform="translate(360,470)"><circle r="20" fill="#f6f0e0" stroke="#2a231d" stroke-width="1.5"/><path d="M0,-16 L5,0 L0,16 L-5,0Z" fill="#b5412d"/><path d="M0,0 L5,0 L0,16 L-5,0Z" fill="#2a231d"/><text y="-23" text-anchor="middle" font-family="Gowun Batang,serif" font-size="12" fill="#2a231d">북</text></g>`;
  s+=`<g transform="translate(20,20) rotate(-3)"><rect width="108" height="40" rx="3" fill="#b5412d"/><rect x="3" y="3" width="102" height="34" rx="2" fill="none" stroke="#f6e7d2" stroke-width="1"/><text x="54" y="29" text-anchor="middle" font-family="Nanum Brush Script,serif" font-size="28" fill="#fff4e6">청솔마을</text></g>`;
  return s;
}

const ART={
  madang:()=>artMadang(false), madang_eve:()=>artMadang(true),
  gongbang:artGongbang, golmok:artGolmok, san:artSan, sikdang:artSikdang,
  jeong:artJeong, bus:artBus, museum:artMuseum, gate:artGate
};
