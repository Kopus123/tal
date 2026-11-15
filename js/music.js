/* ============ MUSIC AND AMBIENCE ============
   Made in the browser with Web Audio: no files to download, nothing to license.
   A place asks for it in its story file:      music calm        sound river
   (tools/check_story.py reads the two lists below, so a typo in a story file is caught.)

   To use a real recording for a mood instead, put the file in audio/music/ and name it in
   MUSIC_FILES (it loops, and replaces the synthesized version of that mood).

   Light on the battery: nothing runs while the volume is off or the app is in the background. */

const MOODS=['none','calm','tense','festival'];
const BEDS=['none','birds','river','market','night','wind','room','bus'];
const MUSIC_FILES={};   // e.g. {calm:'audio/music/calm.mp3'}

let MUS=null,BED=null,WANT={music:'none',sound:'none'},musBus=null,ambBus=null,duckG=null,NOISE=null,mTimer=null;
const PLUCKS={};
const mLevel=()=>[0,.22,.42][S.set.music]||0, aLevel=()=>[0,.16,.32][S.set.amb]||0;
// the audio context only exists after your first tap (browsers insist), so until then we just remember what's wanted
const mctx=()=>AC&&AC.state==='running'?AC:null;

function buses(c){
  if(musBus)return;
  duckG=c.createGain();duckG.connect(c.destination);
  musBus=c.createGain();musBus.gain.value=mLevel();musBus.connect(duckG);
  ambBus=c.createGain();ambBus.gain.value=aLevel();ambBus.connect(duckG);
  const len=c.sampleRate*2;NOISE=c.createBuffer(1,len,c.sampleRate);const d=NOISE.getChannelData(0);
  for(let i=0;i<len;i++)d[i]=Math.random()*2-1;
}
// voices come first: everything else drops while someone is speaking
// HUSH = the phone is open: messages and voicemails need quiet, so everything stays low, and lower still while one plays
let HUSH=false,DUCKED=false;
function duck(on){DUCKED=!!on;const c=mctx();if(!c||!duckG)return;duckG.gain.setTargetAtTime(on?(HUSH?.05:.3):(HUSH?.25:1),c.currentTime,on?.08:.5)}
function hush(on){HUSH=!!on;duck(DUCKED)}
function setVolumes(){const c=mctx();if(!c||!musBus)return;musBus.gain.setTargetAtTime(mLevel(),c.currentTime,.2);ambBus.gain.setTargetAtTime(aLevel(),c.currentTime,.2);syncScene()}

/* ---------- instruments ---------- */
// a plucked string (gayageum-like): a burst of noise fed round a short delay, worked out once per pitch
function pluckBuf(c,f){
  const key=Math.round(f);if(PLUCKS[key])return PLUCKS[key];
  const sr=c.sampleRate,N=Math.max(2,Math.round(sr/f)),len=Math.floor(sr*2.4),b=c.createBuffer(1,len,sr),o=b.getChannelData(0),d=new Float32Array(N);
  let prev=0;for(let i=0;i<N;i++){const r=Math.random()*2-1;prev=d[i]=.6*r+.4*prev}
  for(let i=0;i<len;i++){const k=i%N;o[i]=d[k];d[k]=.4985*(d[k]+d[(k+1)%N])}
  return PLUCKS[key]=b;
}
function pluck(c,out,f,t,vol=.5){const s=c.createBufferSource(),g=c.createGain();s.buffer=pluckBuf(c,f);
  g.gain.setValueAtTime(vol,t);g.gain.setTargetAtTime(0,t+1.2,.5);s.connect(g).connect(out);s.start(t);s.stop(t+2.4)}
function sine(c,out,f,t,dur,vol,f2){const o=c.createOscillator(),g=c.createGain();o.frequency.setValueAtTime(f,t);
  if(f2)o.frequency.exponentialRampToValueAtTime(f2,t+dur);
  g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(vol,t+Math.min(.02,dur/3));g.gain.exponentialRampToValueAtTime(.0001,t+dur);
  o.connect(g).connect(out);o.start(t);o.stop(t+dur+.05)}
function burst(c,out,t,dur,vol,freq,q=1){const s=c.createBufferSource(),f=c.createBiquadFilter(),g=c.createGain();
  s.buffer=NOISE;f.type='bandpass';f.frequency.value=freq;f.Q.value=q;g.gain.setValueAtTime(vol,t);g.gain.exponentialRampToValueAtTime(.0001,t+dur);
  s.connect(f).connect(g).connect(out);s.start(t,Math.random());s.stop(t+dur+.02)}
// things that keep sounding until the scene changes
function hum(c,out,f,vol,type='sine'){const o=c.createOscillator(),g=c.createGain();o.type=type;o.frequency.value=f;g.gain.value=vol;o.connect(g).connect(out);o.start();return o}
function wash(c,out,type,freq,q,vol){const s=c.createBufferSource(),f=c.createBiquadFilter(),g=c.createGain();
  s.buffer=NOISE;s.loop=true;f.type=type;f.frequency.value=freq;f.Q.value=q;g.gain.value=vol;s.connect(f).connect(g).connect(out);s.start(0,Math.random()*2);return {s,f,g}}
function sway(c,param,rate,depth){const o=c.createOscillator(),g=c.createGain();o.frequency.value=rate;g.gain.value=depth;o.connect(g).connect(param);o.start();return o}

/* ---------- music: each mood is a scale, a pace and a drone ---------- */
const hz=n=>440*Math.pow(2,(n-69)/12);
const MOOD={
  // a slow walk up and down a five-note scale over a quiet fifth
  calm:{scale:[50,52,55,57,59,62,64,67,69],drone:[38,45],gap:[.9,2.2],vol:.7},
  // low, sparse, minor; the drone beats against itself
  tense:{scale:[38,41,43,45,48,50,53],drone:[26,26.25],gap:[1.8,4.2],vol:.55,ping:1},
  // a 12-beat drum pattern (굿거리 feel) with the melody on top
  festival:{scale:[57,59,62,64,66,69,71,74],drone:[45],beat:.3,vol:.42,drum:'k.d.kd' + 'k.d.d.'},
};
function startMusic(c,name){
  const m=MOOD[name],g=c.createGain();g.gain.value=0;g.gain.setTargetAtTime(1,c.currentTime,.6);g.connect(musBus);
  const st={name,g,keep:[],next:c.currentTime+.4,i:Math.floor(m.scale.length/2),step:0};
  if(MUSIC_FILES[name]){ // a recording replaces the synthesized mood
    fetch(MUSIC_FILES[name]).then(r=>r.arrayBuffer()).then(ab=>c.decodeAudioData(ab)).then(b=>{if(MUS!==st)return;const s=c.createBufferSource();s.buffer=b;s.loop=true;s.connect(g);s.start();st.keep.push(s)}).catch(()=>{st.file=0});
    st.file=1;return st}
  m.drone.forEach(n=>st.keep.push(hum(c,g,hz(n),name==='tense'?.1:.07)));
  return st;
}
function musicTick(c,st){
  const m=MOOD[st.name];if(st.file)return;
  while(st.next<c.currentTime+.5){const t=st.next;
    if(m.beat){const k=m.drum[st.step%m.drum.length];
      if(k==='k'||k==='K')sine(c,st.g,95,t,.28,.5,52);
      if(k==='d')burst(c,st.g,t,.07,.22,1900,1.2);
      if(st.step%2===0&&Math.random()<.75){st.i=Math.max(0,Math.min(m.scale.length-1,st.i+Math.round(Math.random()*4-2)));pluck(c,st.g,hz(m.scale[st.i]),t,m.vol)}
      st.step++;st.next+=m.beat}
    else{
      st.i=Math.max(0,Math.min(m.scale.length-1,st.i+Math.round(Math.random()*4-2)));
      pluck(c,st.g,hz(m.scale[st.i]),t,m.vol);
      if(Math.random()<.25)pluck(c,st.g,hz(m.scale[Math.max(0,st.i-2)]),t+.18,m.vol*.6);          // a grace note
      if(m.ping&&Math.random()<.3)sine(c,st.g,hz(74+Math.floor(Math.random()*3)*2),t+.6,2.2,.035);  // something far off
      st.next+=m.gap[0]+Math.random()*(m.gap[1]-m.gap[0])}
  }
}

/* ---------- ambience: a bed of sound per kind of place ---------- */
function startBed(c,name){
  const g=c.createGain();g.gain.value=0;g.gain.setTargetAtTime(1,c.currentTime,.8);g.connect(ambBus);
  const st={name,g,keep:[],next:c.currentTime+.5};const K=x=>{st.keep.push(x.s||x);return x};
  if(name==='river'){const w=K(wash(c,g,'bandpass',700,.4,.26));K(sway(c,w.g.gain,.13,.09));K(wash(c,g,'highpass',2500,.5,.06))}
  else if(name==='market'){const w=K(wash(c,g,'bandpass',480,.7,.4));K(sway(c,w.g.gain,.21,.14));const w2=K(wash(c,g,'bandpass',1400,1,.09));K(sway(c,w2.g.gain,.37,.05))}
  else if(name==='wind'){const w=K(wash(c,g,'lowpass',380,.6,.4));K(sway(c,w.f.frequency,.07,220));K(sway(c,w.g.gain,.05,.14))}
  else if(name==='room')K(wash(c,g,'lowpass',180,.5,.16));
  else if(name==='bus'){K(wash(c,g,'lowpass',130,.7,.9));K(hum(c,g,48,.05,'triangle'));const w=K(wash(c,g,'bandpass',900,.6,.05));K(sway(c,w.g.gain,.9,.03))}
  else if(name==='night')K(wash(c,g,'lowpass',260,.5,.1));
  else if(name==='birds')K(wash(c,g,'lowpass',320,.5,.1));
  return st;
}
function bedTick(c,st){
  while(st.next<c.currentTime+.5){const t=st.next,r=Math.random;
    if(st.name==='birds'){const f=2400+r()*1600,n=1+Math.floor(r()*4);for(let i=0;i<n;i++)sine(c,st.g,f*(1+r()*.1),t+i*.13,.09,.3,f*1.25);st.next+=1.2+r()*4.5}
    else if(st.name==='night'){const f=4100+r()*500,n=4+Math.floor(r()*5);for(let i=0;i<n;i++)sine(c,st.g,f,t+i*.07,.035,.15);st.next+=.5+r()*1.6}
    else if(st.name==='river'){sine(c,st.g,900+r()*1800,t,.06+r()*.05,.02,600+r()*900);st.next+=.15+r()*.9}
    else if(st.name==='market'){if(r()<.5)burst(c,st.g,t,.05,.05,2600+r()*1500,3);else sine(c,st.g,300+r()*250,t,.18,.03,260+r()*200);st.next+=.7+r()*2.5}
    else st.next+=2;
  }
}

/* ---------- which scene is playing ---------- */
function fadeOut(c,st){if(!st)return;st.g.gain.cancelScheduledValues(c.currentTime);st.g.gain.setTargetAtTime(0,c.currentTime,.45);
  setTimeout(()=>{st.keep.forEach(n=>{try{n.stop()}catch(e){}});try{st.g.disconnect()}catch(e){}},2600)}
function setScene(music,sound){WANT={music:MOOD[music]?music:'none',sound:BEDS.includes(sound)?sound:'none'};syncScene()}
function syncScene(){
  const c=mctx();if(!c)return;buses(c);
  const wm=mLevel()?WANT.music:'none',ws=aLevel()?WANT.sound:'none';
  if((MUS?MUS.name:'none')!==wm){fadeOut(c,MUS);MUS=wm==='none'?null:startMusic(c,wm)}
  if((BED?BED.name:'none')!==ws){fadeOut(c,BED);BED=ws==='none'?null:startBed(c,ws)}
  if((MUS||BED)&&!mTimer)mTimer=setInterval(()=>{const c=mctx();if(!c||document.hidden)return;if(MUS)musicTick(c,MUS);if(BED)bedTick(c,BED)},150);
  if(!MUS&&!BED&&mTimer){clearInterval(mTimer);mTimer=null}
}
// the first tap wakes the sound; leaving the app puts it to sleep
document.addEventListener('pointerdown',()=>{if(!mLevel()&&!aLevel())return;ac();setTimeout(syncScene,60)});
document.addEventListener('visibilitychange',()=>{if(!AC)return;
  if(document.hidden)AC.suspend();
  else AC.resume().then(()=>{const c=mctx();if(c){if(MUS)MUS.next=c.currentTime+.3;if(BED)BED.next=c.currentTime+.3}syncScene()})});
