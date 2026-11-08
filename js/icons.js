/* ============ WORD PICTURES ============
   Every word in the story's "=== words" list points at one of these: "봤어요 = eye +past".
   64 x 64 drawings in one style: ink outline, hanji fill, dancheong accents.
   Badges always mean the same thing:
     +past    ochre circle, top-left, arrow turning back   (it already happened)
     +future  green circle, top-right, arrow turning ahead (it hasn't happened yet)
     +not     red slash across the picture                 (not / none / don't)          */

const IK='#2a231d',IG='#3f8b77',IO='#d9a43d',IR='#b5412d',IS='#e9c9a3',IP='#f6f0e0',IB='#4f6ea8',IW='#8a5a34';
const st=(w=3)=>`stroke="${IK}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"`;
const P=(d,f='none',w=3)=>`<path d="${d}" fill="${f}" ${st(w)}/>`;
const Ci=(x,y,r,f='none',w=3)=>`<circle cx="${x}" cy="${y}" r="${r}" fill="${f}" ${st(w)}/>`;
const Re=(x,y,w,h,rx,f='none',sw=3)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${f}" ${st(sw)}/>`;
const Tx=(x,y,t,sz=20,f=IK)=>`<text x="${x}" y="${y}" text-anchor="middle" font-family="Gowun Dodum,sans-serif" font-weight="700" font-size="${sz}" fill="${f}">${t}</text>`;

// a figure: head + shoulders
function fig(x,y,s,body,hair,o={}){
  let g=`<g transform="translate(${x},${y}) scale(${s})">`;
  g+=P('M-16,22 Q-15,4 0,3 Q15,4 16,22Z',body);
  if(o.long)g+=P('M-11,-10 Q-13,4 -10,8 L10,8 Q13,4 11,-10Z',hair,0);
  g+=Ci(0,-9,10,IS);
  if(o.bun)g+=Ci(0,-22,4.5,hair,2.5);
  g+=P('M-10,-11 Q-9,-21 0,-21 Q9,-21 10,-11 Q5,-16 0,-16 Q-5,-16 -10,-11Z',hair,2);
  g+=P('M-4.5,-8 q1.5,-1.6 3,0 M1.5,-8 q1.5,-1.6 3,0',`none`,1.8)+P('M-3,-3 q3,2.4 6,0','none',1.8);
  return g+'</g>';
}
const arrowR=(x1,y,x2,w=4)=>P(`M${x1},${y} L${x2},${y} M${x2-8},${y-8} L${x2},${y} L${x2-8},${y+8}`,'none',w);

const ICON={
  grandma:()=>fig(32,34,1.25,'#8a6a9a','#d8d4ce',{bun:1}),
  woman:()=>fig(32,34,1.25,'#c26a86','#2a1d18',{long:1}),
  youngman:()=>fig(32,34,1.25,IB,'#2a1d18'),
  me:()=>fig(26,34,1.15,IG,'#2a1d18')+P('M52,30 L40,40 M40,32 L40,40 L48,40','none',3),
  two:()=>fig(21,36,.95,IG,'#2a1d18')+fig(43,36,.95,IB,'#2a1d18'),
  together:()=>fig(20,34,.9,IG,'#2a1d18')+fig(44,34,.9,IB,'#2a1d18')+P('M30,50 Q32,44 34,50',IO,3),
  teacher:()=>fig(24,34,1.05,'#5b6a7a','#2a1d18')+Re(38,30,20,24,2,IP)+P('M48,30 V54','none',2),
  eye:()=>P('M6,32 Q32,8 58,32 Q32,56 6,32Z',IP)+Ci(32,32,9,'#6a4a32')+`<circle cx="32" cy="32" r="3.5" fill="${IK}"/>`,
  yes:()=>`<circle cx="32" cy="32" r="18" fill="none" stroke="${IG}" stroke-width="7"/>`,
  no:()=>`<path d="M16,16 L48,48 M48,16 L16,48" stroke="${IR}" stroke-width="7" stroke-linecap="round"/>`,
  bang:()=>P('M10,12 H54 V44 H30 L18,54 V44 H10Z',IP)+P('M32,18 V32','none',5)+`<circle cx="32" cy="39" r="2.8" fill="${IK}"/>`,
  where:()=>P('M32,58 C20,42 14,34 14,26 A18,18 0 0 1 50,26 C50,34 44,42 32,58Z',IR)+Tx(32,33,'?',20,'#fff'),
  exists:()=>P('M8,52 H56','none',3)+Re(20,30,24,22,3,IO)+P('M46,12 L48,18 L54,20 L48,22 L46,28 L44,22 L38,20 L44,18Z',IO,2),
  room:()=>Re(16,8,32,48,2,IW)+Re(20,12,24,40,1,IP,2)+P('M32,12 V52 M20,25 H44 M20,38 H44','none',2),
  yard:()=>P('M6,30 Q20,26 32,16 Q44,26 58,30 L52,30 L52,40 L12,40 L12,30Z','#3b4048')+Re(4,42,56,14,2,'#d8c7a3')+Ci(50,46,4,IG,2),
  strange:()=>Ci(32,34,20,IS)+P('M20,24 L28,20 M37,26 L45,26','none',3)+Ci(25,31,2,IK,1)+Ci(40,32,2,IK,1)+P('M23,44 q3,-3 6,0 t6,0 t6,0','none',2.5)+Tx(54,16,'?',16,IR),
  phone:()=>Re(20,6,24,52,6,'#e9a3b4')+Re(24,12,16,34,2,'#1b1f27',2)+P('M27,18 L33,26 L30,30 L36,38','none',1.5).replace(IK,'#9aa3b3')+Ci(32,51,2,'none',2),
  here:()=>`<ellipse cx="32" cy="52" rx="20" ry="6" fill="${IO}" stroke="${IK}" stroke-width="3"/>`+P('M32,8 V40 M22,30 L32,40 L42,30','none',4),
  that:()=>P('M6,40 H36','none',3)+P('M38,40 H44','none',3)+P('M28,32 L36,40 L28,48','none',3)+Re(48,32,12,12,2,IO,2.5),
  this:()=>P('M6,32 H26 M18,24 L26,32 L18,40','none',4)+Re(32,20,26,26,3,IO),
  search:()=>Ci(26,26,15,'#dbe8ee')+P('M37,37 L54,54','none',7),
  workshop:()=>Re(8,36,34,18,2,IW)+P('M30,30 L52,8','none',4)+P('M26,34 L34,26 L38,30 L30,38Z','#b8b8b8',2.5),
  mask:()=>`<g transform="translate(32,33) scale(1.55)"><ellipse rx="14" ry="18" fill="#e7d2a7" stroke="${IK}" stroke-width="1.8"/><path d="M-11,-9 Q-6,-14 -1,-9 M1,-9 Q6,-14 11,-9" stroke="${IK}" stroke-width="1.8" fill="none"/><path d="M-9,-3 Q-5,-7 -2,-3 M2,-3 Q5,-7 9,-3" stroke="${IK}" stroke-width="1.6" fill="none"/><path d="M-9,6 Q0,16 9,6 Q0,10 -9,6Z" fill="#5a2a1d"/><circle cx="-9" cy="3" r="2.6" fill="#c45a45" opacity=".55"/><circle cx="9" cy="3" r="2.6" fill="#c45a45" opacity=".55"/></g>`,
  pretty:()=>[0,72,144,216,288].map(a=>`<ellipse cx="32" cy="20" rx="8" ry="12" fill="#e9a3b4" stroke="${IK}" stroke-width="2.5" transform="rotate(${a} 32 34)"/>`).join('')+Ci(32,34,6,IO,2.5)+P('M52,8 L54,13 L59,15 L54,17 L52,22 L50,17 L45,15 L50,13Z',IO,1.5),
  thanks:()=>`<g transform="rotate(35 32 52)">${fig(32,38,1.1,IG,'#2a1d18')}</g>`+P('M8,58 H56','none',3),
  sleep:()=>P('M40,10 A22,22 0 1 0 54,42 A17,17 0 1 1 40,10Z',IO)+Tx(16,22,'z',14)+Tx(24,14,'z',10),
  festival:()=>P('M3,10 Q32,24 61,10','none',2)+[[9,13,IR],[19,17,IO],[29,19,IG],[39,18.5,IB],[49,16,IR],[57,12.5,IO]].map(([x,y,c])=>`<path d="M${x-4.5},${y} L${x+4.5},${y+.5} L${x},${y+10}Z" fill="${c}" stroke="${IK}" stroke-width="1.4" stroke-linejoin="round"/>`).join('')
    +[0,45,90,135,180,225,270,315].map((a,i)=>{const r=Math.PI*a/180,c=i%2?IR:IO;return `<path d="M${(32+Math.cos(r)*5).toFixed(1)},${(45+Math.sin(r)*5).toFixed(1)} L${(32+Math.cos(r)*13).toFixed(1)},${(45+Math.sin(r)*13).toFixed(1)}" stroke="${c}" stroke-width="3" stroke-linecap="round"/><circle cx="${(32+Math.cos(r)*16).toFixed(1)}" cy="${(45+Math.sin(r)*16).toFixed(1)}" r="1.8" fill="${c}"/>`}).join('')+`<circle cx="32" cy="45" r="2.5" fill="${IO}"/>`,
  lantern:()=>P('M32,4 V12','none',2.5)+`<ellipse cx="32" cy="32" rx="16" ry="20" fill="${IR}" stroke="${IK}" stroke-width="3"/>`+P('M22,20 Q32,32 22,44 M42,20 Q32,32 42,44','none',2)+Re(26,10,12,4,1,IK,0)+Re(26,50,12,4,1,IK,0)+P('M32,54 V62','none',2.5),
  calendar:()=>Re(10,12,44,44,4,IP)+Re(10,12,44,11,4,IR)+P('M20,6 V16 M44,6 V16','none',3)+[0,1,2].map(r=>[0,1,2,3].map(c=>`<rect x="${16+c*9}" y="${28+r*8}" width="6" height="5" fill="#d1c4a6"/>`).join('')).join(''),
  today:()=>ICON.calendar()+`<circle cx="34" cy="38" r="8" fill="${IO}" stroke="${IR}" stroke-width="2.5"/>`,
  morning:()=>P('M8,46 H56','none',3)+P('M16,46 A16,16 0 0 1 48,46Z',IO)+P('M32,22 V14 M16,30 L10,24 M48,30 L54,24','none',3),
  clock:()=>Ci(32,32,24,IP)+P('M32,32 V16 M32,32 H20','none',4)+Ci(32,32,2.5,IK,1),
  excuse:()=>fig(28,38,1,IG,'#2a1d18')+P('M42,40 L48,12','none',5)+Ci(48,10,4,IS,2.5),
  wave:()=>P('M22,52 L22,26 Q22,22 25,22 Q28,22 28,26 V20 Q28,16 31,16 Q34,16 34,20 V22 Q34,18 37,18 Q40,18 40,22 V28 Q40,24 43,24 Q46,24 46,28 V44 Q46,54 36,56 L28,56 Q22,56 22,52Z',IS,2.5)+P('M10,18 Q8,24 10,30 M54,10 Q58,14 58,20','none',2.5),
  welcome:()=>Re(10,8,26,48,2,IW)+P('M36,8 L52,14 V50 L36,56Z',IP,3)+P('M42,18 V46','none',1.5)+Ci(46,32,2,IK,1),
  photo:()=>Re(8,12,48,40,3,IP)+P('M12,46 L26,28 L34,38 L40,32 L52,46Z',IG,2.5)+Ci(44,22,4,IO,2),
  camera:()=>Re(8,18,48,34,5,'#3b4048')+Re(22,12,14,8,2,'#3b4048')+Ci(32,35,11,'#dbe8ee')+Ci(32,35,5,IB,2)+P('M48,8 L52,14 M56,10 L52,14 M54,4 L52,14','none',2).replace(IK,IO),
  please:()=>P('M6,36 Q10,52 30,52 L30,44 Q18,44 14,36Z',IS,2.5)+P('M58,36 Q54,52 34,52 L34,44 Q46,44 50,36Z',IS,2.5)+P('M26,18 L32,30 L38,18','none',3),
  hungry:()=>P('M8,34 H56 Q54,54 32,54 Q10,54 8,34Z',IP)+P('M20,26 q4,-6 0,-12 M32,26 q4,-6 0,-12 M44,26 q4,-6 0,-12','none',2).replace(IK,'#9aa3b3')+Tx(32,49,'?',14,IR),
  kimchi:()=>P('M14,50 Q8,30 22,14 Q34,6 46,14 Q58,30 50,50Z','#e8e2c0')+P('M20,46 Q24,24 32,14 M44,46 Q40,24 32,14','none',2.5)+P('M18,40 Q26,30 30,36 Q36,26 46,34','none',4).replace(IK,IR),
  restaurant:()=>P('M8,34 H56 Q54,54 32,54 Q10,54 8,34Z','#f4f1ea')+P('M40,8 L30,30 M48,10 L36,30','none',3)+P('M16,26 q3,-5 0,-10 M24,26 q3,-5 0,-10','none',2),
  gimbap:()=>[[18,32],[38,24],[38,44]].map(([x,y])=>Ci(x,y,11,'#1f2a22')+`<circle cx="${x}" cy="${y}" r="7" fill="#f4f1ea"/><circle cx="${x}" cy="${y}" r="3" fill="${IO}"/><circle cx="${x+2}" cy="${y-2}" r="1.6" fill="${IG}"/>`).join(''),
  tteokbokki:()=>`<ellipse cx="32" cy="42" rx="26" ry="12" fill="${IP}" stroke="${IK}" stroke-width="3"/>`+[[20,36],[32,40],[44,35],[26,46],[40,46]].map(([x,y])=>`<rect x="${x-7}" y="${y-3}" width="14" height="7" rx="3.5" fill="${IR}" stroke="${IK}" stroke-width="1.5"/>`).join(''),
  ramen:()=>P('M6,30 H58 Q56,56 32,56 Q8,56 6,30Z',IO)+P('M14,30 q4,-6 8,0 t8,0 t8,0 t8,0 t8,0','none',2.5)+P('M44,4 L34,30 M52,6 L40,30','none',3),
  bibimbap:()=>Ci(32,32,24,'#3b4048')+P('M32,32 L32,10 A22,22 0 0 1 51,22Z',IG,1.5)+P('M32,32 L51,22 A22,22 0 0 1 48,46Z',IO,1.5)+P('M32,32 L48,46 A22,22 0 0 1 18,48Z',IR,1.5)+P('M32,32 L18,48 A22,22 0 0 1 12,22Z','#8a5a34',1.5)+P('M32,32 L12,22 A22,22 0 0 1 32,10Z','#e8e2c0',1.5)+Ci(32,32,7,'#fff',2)+`<circle cx="32" cy="32" r="3.5" fill="${IO}"/>`,
  water:()=>P('M32,6 Q48,28 48,40 A16,16 0 0 1 16,40 Q16,28 32,6Z','#9fc6e0')+P('M24,40 Q24,46 30,48','none',2).replace(IK,'#fff'),
  yum:()=>Ci(32,32,24,IO)+P('M20,26 q3,-4 6,0 M38,26 q3,-4 6,0','none',3)+P('M18,38 Q32,50 46,38','none',3)+P('M32,44 q0,10 6,8 q4,-2 2,-8','#e07b8a',2),
  spicy:()=>P('M12,50 Q12,30 32,22 Q44,18 46,10 Q52,22 44,34 Q34,52 12,50Z',IR)+P('M44,12 Q42,6 48,4','none',3).replace(IK,IG)+P('M52,36 q2,4 0,6 M56,26 q2,4 0,6','none',2.5).replace(IK,'#5aa0d0'),
  salty:()=>Re(20,24,24,34,6,IP)+P('M20,30 H44','none',2)+Re(22,12,20,12,4,'#b8b8b8')+[[28,16],[36,16],[32,20]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="1.4" fill="${IK}"/>`).join('')+P('M10,10 l2,2 M54,8 l-2,2 M8,22 l3,0','none',2),
  twoitems:()=>Ci(20,34,12,IO)+Ci(44,34,12,IO)+Tx(20,40,'1',14)+Tx(44,40,'2',14),
  bag:()=>P('M12,22 H52 L48,58 H16Z',IO)+P('M22,22 Q22,8 32,8 Q42,8 42,22','none',3),
  bus:()=>Re(4,16,56,32,6,IB)+Re(10,22,10,10,1,'#dbe8ee',2)+Re(24,22,10,10,1,'#dbe8ee',2)+Re(38,22,10,10,1,'#dbe8ee',2)+Ci(16,50,5,'#3b4048')+Ci(48,50,5,'#3b4048'),
  busstop:()=>P('M32,30 V60','none',4)+Ci(32,18,14,IB)+`<rect x="24" y="13" width="16" height="9" rx="2" fill="#fff"/><circle cx="27" cy="23" r="1.6" fill="#fff"/><circle cx="37" cy="23" r="1.6" fill="#fff"/>`,
  stop:()=>P('M32,30 V60','none',4)+Ci(32,18,14,IR)+P('M24,18 H40','none',4).replace(IK,'#fff'),
  now:()=>P('M6,40 H58','none',3)+Ci(12,40,4,IP,2.5)+Ci(32,40,8,IO)+Ci(52,40,4,IP,2.5)+P('M32,8 V24 M26,18 L32,24 L38,18','none',3),
  board:()=>Re(26,8,32,48,4,IB)+Re(32,14,20,30,2,'#dbe8ee',2)+fig(16,40,.75,IG,'#2a1d18')+P('M22,20 L30,20 M26,16 L30,20 L26,24','none',2.5),
  getoff:()=>P('M6,30 H30 V56 H58','none',3)+fig(44,30,.8,IG,'#2a1d18')+P('M18,14 V26 M13,21 L18,26 L23,21','none',3),
  beside:()=>Re(6,22,20,20,3,IO)+Re(38,22,20,20,3,IG)+P('M26,52 H38','none',2.5)+P('M28,48 L24,52 L28,56 M36,48 L40,52 L36,56','none',2),
  right:()=>arrowR(8,32,54,6),
  left:()=>`<g transform="translate(64,0) scale(-1,1)">${arrowR(8,32,54,6)}</g>`,
  go:()=>fig(20,36,.9,IG,'#2a1d18')+arrowR(36,36,58,4),
  fast:()=>P('M36,4 L16,36 H30 L26,60 L48,26 H34Z',IO),
  mountain:()=>P('M4,54 L24,18 L36,38 L44,28 L60,54Z',IG)+P('M18,29 L24,18 L30,29 Q24,26 18,29Z','#fff',2),
  market:()=>Re(8,30,48,26,2,IP)+P('M6,30 L10,14 H54 L58,30Z',IP)+[14,26,38,50].map(x=>`<path d="M${x-2},14 L${x-4},30 H${x+4} L${x+4},14Z" fill="${IR}"/>`).join('')+Ci(20,40,4,IO,2)+Ci(32,40,4,IG,2)+Ci(44,40,4,IR,2),
  cinema:()=>Re(8,24,48,32,3,'#3b4048')+P('M8,14 L54,8 L56,20 L10,26Z','#3b4048')+P('M18,13 L22,23 M30,11 L34,21 M42,10 L46,19','none',3).replace(IK,'#fff'),
  museum:()=>P('M6,22 L32,6 L58,22Z',IP)+Re(8,22,48,4,0,IP)+[14,26,38,50].map(x=>Re(x-3,28,6,20,0,IP,2.5)).join('')+Re(6,50,52,6,0,IP),
  subway:()=>Re(12,6,40,44,8,IG)+Re(18,12,28,16,2,'#dbe8ee',2)+Ci(22,38,3,'#fff',2)+Ci(42,38,3,'#fff',2)+P('M18,50 L12,60 M46,50 L52,60','none',3),
  meet:()=>fig(16,36,.85,IG,'#2a1d18')+fig(48,36,.85,IB,'#2a1d18')+P('M26,46 Q32,40 38,46',IO,3),
  not:()=>`<circle cx="32" cy="32" r="22" fill="none" stroke="${IR}" stroke-width="6"/><path d="M17,47 L47,17" stroke="${IR}" stroke-width="6" stroke-linecap="round"/>`,
  come:()=>Re(36,10,22,44,2,IW)+P('M6,32 H30 M22,24 L30,32 L22,40','none',4),
  unknown:()=>Tx(32,42,'?',30,'#9a8f7d')
};

const BADGE={
  past:`<circle cx="13" cy="13" r="11" fill="${IO}" stroke="${IK}" stroke-width="2.5"/><path d="M18,9 A6.5,6.5 0 1 0 19,15" fill="none" stroke="${IK}" stroke-width="2.5" stroke-linecap="round"/><path d="M14,5 L18.5,9 L13.5,11.5" fill="none" stroke="${IK}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>`,
  future:`<rect x="39" y="2" width="23" height="22" rx="5" fill="${IG}" stroke="${IK}" stroke-width="2.5"/><path d="M44,7.5 L49.5,13 L44,18.5 M51.5,7.5 L57,13 L51.5,18.5" fill="none" stroke="#fff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>`,
  not:`<path d="M8,56 L56,8" stroke="#fff" stroke-width="10" stroke-linecap="round"/><path d="M8,56 L56,8" stroke="${IR}" stroke-width="6" stroke-linecap="round"/>`
};

// "eye +past" -> SVG string
function iconSVG(spec,cls=''){
  const parts=String(spec||'unknown').trim().split(/\s+/);
  const base=ICON[parts[0]]?parts[0]:'unknown';
  let inner=ICON[base]();
  const mods=parts.slice(1).map(p=>p.replace('+',''));
  if(mods.includes('past')||mods.includes('future'))inner=`<g transform="translate(6,8) scale(.86)">${inner}</g>`;
  if(mods.includes('not'))inner+=BADGE.not;
  if(mods.includes('past'))inner+=BADGE.past;
  if(mods.includes('future'))inner+=BADGE.future;
  return `<svg viewBox="0 0 64 64" class="${cls}" aria-hidden="true">${inner}</svg>`;
}
