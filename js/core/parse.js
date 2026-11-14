/* ============ ENGINE ============
   Reads story/*.story and runs it. Nothing about the plot lives in this file. */

let WORLD=null;       // story/world.story: cast, words, chapters, map, grammar
let CH={};            // chapter id -> parsed chapter file
let ST=null;          // the current chapter, merged with the world
let W={};             // every word in every chapter -> {p: picture spec, g: grammar, def}

/* ---------- story parser ---------- */
// split "a | b | {x|y}" on the bars that aren't inside {braces}
function splitBar(str){const out=[];let d=0,cur='';for(const c of str){if(c==='{')d++;else if(c==='}')d--;if(c==='|'&&!d){out.push(cur.trim());cur=''}else cur+=c}out.push(cur.trim());return out}
function parseStory(src,st){
  st=st||{cast:{},words:{},places:{},nodes:{},cases:[],phones:[],hints:[],patterns:[],meta:{},chapters:[],map:[],grammar:{},endings:[],evidence:{},statements:{},tells:{},examines:{},meanings:{},names:{}};
  let sec=null,cur=null,scene=null,last=null,count=0;
  const node=n=>{count++;const id=count===1?scene:scene+'.'+count;
    if(last&&!last.next&&!last.rewind&&!last.ch&&!last.ans)last.next=id;
    n.id=id;st.nodes[id]=n;last=n;return n};
  const fx=s=>s.split(';').map(x=>x.trim()).filter(Boolean).map(x=>{
    const m=x.match(/^(\w+)\s+(.+?)(?:\s+if\s+(\S+))?$/);return m?{k:m[1],a:m[2].trim(),c:m[3]}:null}).filter(Boolean);
  const nl=s=>s.replace(/\\n/g,'\n');
  src.split(/\r?\n/).forEach((raw,ln)=>{
    const line=raw.trim();if(!line||line.startsWith('#'))return;
    const h=line.match(/^===\s*(\w+)\s*(.*)$/);
    if(h){sec=h[1];const arg=h[2].trim();
      if(sec==='scene'){scene=arg;last=null;count=0}
      else if(sec==='place')cur=st.places[arg]={id:arg,spots:[],glow:[],desc:[]};
      else if(sec==='phone'){cur={id:arg,m:[],fx:[]};st.phones.push(cur)}
      else if(sec==='pattern'){cur={id:arg,pairs:[],need:3};st.patterns.push(cur)}
      else if(sec==='examine')cur=st.examines[arg]={id:arg,details:[]};
      return}
    let m;
    switch(sec){
      case 'meta':{const i=line.indexOf(' ');st.meta[line.slice(0,i)]=line.slice(i+1).trim();break}
      // every word and line carries a language (meta "lang", default ko); "who@ja: ..." overrides one line
      case 'cast':{const [k,n,c,v,look]=line.split('|').map(s=>s.trim());st.cast[k]={n,c,voice:!!v,look:look||''};break}
      case 'chapters':{const [id,t,sub,file,cont]=line.split('|').map(s=>(s||'').trim());st.chapters.push({id,t,sub,file,cont:!!cont});break}
      case 'map':{m=line.match(/^pin\s+(\S+)\s+([\d.]+)\s+([\d.]+)/);if(m)st.map.push({p:m[1],x:+m[2],y:+m[3]});break}
      case 'words':{m=line.match(/^(.+?)\s*=\s*(.+)$/);if(m)st.words[m[1]]=Object.assign(m[2]==='(grammar)'?{g:1}:{p:m[2]},{lang:st.meta.lang||'ko'});break}
      case 'grammar':{const i=line.indexOf('|');if(i>0)st.grammar[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      // tells: grammar that gives people away. "piece | what it gives away" (shown once you've caught one)
      case 'tells':{const i=line.indexOf('|');if(i>0)st.tells[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      case 'meanings':{const i=line.indexOf('|');if(i>0)st.meanings[line.slice(0,i).trim()]=line.slice(i+1).trim();break}
      case 'names':{const [n,k,d]=line.split('|').map(x=>(x||'').trim());if(n)st.names[n]={kind:k||'name',d};break}
      case 'endings':{const i=line.indexOf('|');if(i>0)st.endings.push({k:line.slice(0,i).trim(),d:line.slice(i+1).trim()});break}
      case 'hints':{m=line.match(/^if\s+(\S+):\s*(.+)$/);st.hints.push(m?{c:m[1],t:m[2]}:{t:line});break}
      // deduction: ID [final] if COND | sentence with {blank} words | what it means once solved
      case 'deduce':{m=line.match(/^(\w+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        // "... | why | needs A + B": the deduction also needs these two proofs attached (evidence or statement ids; A/B2 = either)
        if(m){let why=m[5],needs=null;const k=why.match(/^(.*?)\s*\|\s*needs\s+(.+)$/);if(k){why=k[1];needs=[];k[2].split('+').forEach(x=>{const h=x.match(/"([^"]*)"/);const ids=x.replace(/"[^"]*"/,'').trim();
          const alts=ids.split('/').map(y=>y.trim());alts.hint=h?h[1]:'';needs.push(alts)})}
        st.cases.push({id:m[1],final:!!m[2],c:m[3],text:m[4],why,needs,blanks:[...m[4].matchAll(/\{([^}|]+)(?:\|([^}]+))?\}/g)].map(x=>x[2]||x[1])})}break}
      // evidence: id | label | picture | what it is | Korean written on it (optional)
      case 'evidence':{const [id,label,icon,desc,...kor]=line.split('|').map(x=>(x||'').trim());st.evidence[id]={id,label,icon,desc,ko:kor.join('|')};break} // the Korean may contain {a|b} tokens
      case 'case':{m=line.match(/^(\w+)\s+(\S+)(\s+final)?\s+if\s+(\S+)\s*\|\s*(.+?)\s*\|\s*(.+)$/);
        if(m)st.cases.push({id:m[1],a:m[2],final:!!m[3],c:m[4],q:m[5],why:m[6]});break}
      // examine: art KEY / prompt TEXT / detail ID X% Y% R [key] | what you notice ! effects
      case 'examine':{
        if(m=line.match(/^(art|prompt|compare)\s+(.+)$/))cur[m[1]]=m[2];
        else if(m=line.match(/^detail\s+(\w+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(\s+key)?\s*\|\s*(.+?)(?:\s+!\s+(.+))?$/))
          cur.details.push({id:m[1],x:+m[2],y:+m[3],r:+m[4],key:!!m[5],t:m[6],fx:m[7]?fx(m[7]):[]});
        break}
      case 'pattern':{if(m=line.match(/^title\s+(.+)/))cur.title=m[1];else if(m=line.match(/^note\s+(.+)/))cur.note=m[1];
        else if(m=line.match(/^need\s+(\d+)/))cur.need=+m[1];else if(m=line.match(/^(.+?)\s*>\s*(.+)$/))cur.pairs.push([m[1],m[2]]);break}
      case 'place':{
        if(m=line.match(/^(name|sub|art|first|always|ambient|travel)\s+(.+)$/))cur[m[1]]=m[2];
        else if(m=line.match(/^desc\s+(?:if\s+(\S+):\s*)?(.+)$/))cur.desc.push({c:m[1],t:m[2]});
        else if(m=line.match(/^spot\s+"([^"]+)"\s+([\d.]+)\s+([\d.]+)\s+(->|=>)\s+(.+?)(?:\s+if\s+(\S+))?$/))
          cur.spots.push({l:m[1],x:+m[2],y:+m[3],kind:m[4],t:m[5],c:m[6]});
        // glow WORD X Y [R] [H]: a circle of radius R% of the width, or an ellipse R wide and H tall (% of the height)
        else if(m=line.match(/^glow\s+(.+?)\s+([\d.]+)\s+([\d.]+)(?:\s+([\d.]+))?(?:\s+([\d.]+))?$/))cur.glow.push({w:m[1],x:+m[2],y:+m[3],r:+(m[4]||8),h:m[5]?+m[5]:0});
        break}
      case 'phone':{
        if(m=line.match(/^name\s+(.+)/))cur.name=m[1];
        else if(m=line.match(/^avatar\s+(\S+)\s+(\S+)/)){cur.av=m[1];cur.c=m[2]}
        else if(m=line.match(/^on-open\s+(.+)/))cur.fx=fx(m[1]);
        // "them@FLAG ..." = this message only arrives once FLAG is set
        else if(m=line.match(/^day(?:@(\S+))?\s+(.+)/))cur.m.push({d:m[2],c:m[1]});
        else if(m=line.match(/^(them|me)(?:@(\S+))?\s+(\S+)\s+(.+)/))cur.m.push({me:m[1]==='me',c:m[2],t:m[3],ko:m[4]});
        else if(m=line.match(/^sys(?:@(\S+))?\s+(.+)/))cur.m.push({sys:1,c:m[1],ko:m[2]});
        // "voice@FLAG 13:20 who 한국어" = a voicemail: sound only
        else if(m=line.match(/^voice(?:@(\S+))?\s+(\S+)\s+([a-z_]+)\s+(.+)/))cur.m.push({vm:1,c:m[1],t:m[2],who:m[3],ko:m[4]});
        else if(m=line.match(/^note(?:@(\S+))?\s+(.+)/)){cur.note=m[2];cur.noteC=m[1]}
        break}
      case 'scene':{
        if(line.startsWith('~'))node({who:'narr',en:line.slice(1).trim()});
        else if(m=line.match(/^\((.*)\)$/)){if(last)last.en=m[1]}
        else if(line.startsWith('!')){if(last){const f=fx(line.slice(1));last.fx=(last.fx||[]).concat(f);
          f.filter(e=>e.k==='statement').forEach(e=>st.statements[e.a]={id:e.a,node:last.id})}}
        // "* label -> TARGET [if COND] [! effects]": the choice only shows when COND holds
        else if(m=line.match(/^\*\s+(.+?)\s+->\s+(.+?)(?:\s+if\s+(\S+))?(?:\s+!\s+(.+))?$/)){
          const lab=m[1],o={go:m[2],c:m[3],fx:m[4]?fx(m[4]):[]};
          if(lab.startsWith('['))o.en=lab.replace(/^\[|\]$/g,'');else{o.ko=lab;o.lang=st.meta.lang||'ko'}(last.ch=last.ch||[]).push(o)}
        else if(m=line.match(/^->\s*(.+)$/)){if(last)last.next=m[1].trim()}
        else if(m=line.match(/^<-\s*(.+)$/)){if(last)last.rewind=m[1].trim()}
        else if(m=line.match(/^@build\s+(.+)$/))node({type:'build',en:m[1],tiles:[],ans:[]});
        else if(m=line.match(/^tiles:\s*(.+)$/))last.tiles=splitBar(m[1]);
        // "@type prompt | who": who answers small talk (hello, thanks) while you work on it
        else if(m=line.match(/^@type\s+(.+)$/)){const k=m[1].match(/^(.*?)\s*\|\s*([a-z_]+)$/);node({type:'type',en:k?k[1]:m[1],to:k?k[2]:null,ans:[]})}
        // "@number prompt | time|won|phone|count": a number pad; answers are compared digit by digit
        else if(m=line.match(/^@number\s+(.+?)(?:\s*\|\s*(time|won|phone|count))?$/))node({type:'number',en:m[1],kind:m[2]||'count',ans:[]});
        else if(m=line.match(/^answer:\s*(.+?)\s+->\s+(.+)$/))last.ans.push([last.type==='type'||last.type==='number'?m[1].trim():splitBar(m[1]),m[2].trim()]);
        else if(m=line.match(/^miss\s+->\s+(.+)$/))last.miss=m[1].trim();
        else if(m=line.match(/^@camera\s+(?:([\d.]+)\s+([\d.]+)\s*\|\s*)?(.+)$/))node({type:'camera',tx:+(m[1]||50),ty:+(m[2]||50),en:m[3]});
        else if(m=line.match(/^@photo\s+(.+)$/))node({type:'photo',en:m[1]});
        else if(m=line.match(/^@present\s+(.+)$/))node({type:'present',en:m[1],shows:[]});
        else if(m=line.match(/^show:\s*(\S+)\s+->\s+(.+)$/))last.shows.push([m[1],m[2].trim()]);
        // "@contradict prompt" then "pair: A + B -> TARGET" (A/B = statement or evidence ids, either order)
        else if(m=line.match(/^@examine\s+(\w+)$/))node({type:'examine',exam:m[1]});
        else if(m=line.match(/^@contradict\s+(.+)$/))node({type:'contradict',en:m[1],pairs:[]});
        else if(m=line.match(/^pair:\s*(\S+)\s*\+\s*(\S+)\s+->\s+(.+)$/))last.pairs.push([[m[1],m[2]],m[3].trim()]);
        else if(m=line.match(/^@card\s+(.+?)(?:\s*\|\s*(.+))?$/))node({type:'card',title:m[1],sub:m[2]||''});
        // "who[audio]: ..." = you only hear it: no text until you've acted on it ("who[sad audio]" works too)
        else if(m=line.match(/^([a-z_]+)(?:\[([\w ]+)\])?(?:@([a-z]{2}))?:\s*(.+)$/)){const tags=(m[2]||'').split(/\s+/).filter(Boolean);
          node({who:m[1],ex:tags.find(t=>t!=='audio')||'neutral',audio:tags.includes('audio'),ko:nl(m[4]),lang:m[3]||st.meta.lang||'ko'})}
        else console.warn('story line not understood',ln+1,line);
        break}
    }
  });
  return st;
}
