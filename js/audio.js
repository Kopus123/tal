/* ============ SOUND ============
   Voices, sound effects and vibration. */

/* ---------- voice (Web Audio, so phones don't show a media-player notification) ---------- */
let VOICE=null,SRC=null,TOKEN=0;const BUF={};
function pickVoice(){const vs=speechSynthesis.getVoices();VOICE=vs.find(v=>/^ko/i.test(v.lang)&&/google/i.test(v.name))||vs.find(v=>/^ko/i.test(v.lang))||null}
if('speechSynthesis' in window){pickVoice();speechSynthesis.onvoiceschanged=pickVoice}
// must match normalize() in tools/build_audio.py
const normT=s=>plain(s).replace(/[📸🏮^♡✖📞🔔💙]/gu,'').replace(/\//g,', ').replace(/\s+/g,' ').trim();
const vg=who=>ST&&ST.cast[who]&&ST.cast[who].voice?who:'sign';
const clipFor=(text,who)=>window.AUDIO&&window.AUDIO[vg(who)+'|'+normT(text)];
async function buffer(url){if(BUF[url])return BUF[url];const c=ac();const ab=await(await fetch(url)).arrayBuffer();
  const b=await new Promise((res,rej)=>c.decodeAudioData(ab,res,rej));BUF[url]=b;return b}
function stopAudio(){TOKEN++;if(SRC){try{SRC.onended=null;SRC.stop()}catch(e){}SRC=null}if('speechSynthesis' in window)speechSynthesis.cancel()}
// Resolves when the line finishes (or after 8s at most), so callers can wait for it.
function speak(text,who){
  stopAudio();const my=TOKEN;
  return new Promise(async done=>{
    const t=normT(text);if(!t)return done();
    const cap=setTimeout(done,8000),fin=()=>{clearTimeout(cap);done()};
    const f=clipFor(text,who);
    if(f){try{const b=await buffer(f);if(my!==TOKEN)return fin();const c=ac();
      const s=c.createBufferSource();s.buffer=b;s.playbackRate.value=S.set.slow?.82:1;s.connect(c.destination);
      s.onended=()=>{if(SRC===s)SRC=null;fin()};SRC=s;s.start();return}catch(e){}}
    if(my!==TOKEN)return fin();tts(t,fin);
  });
}
// a sentence you built: one recording if it exists, otherwise your voice saying each piece
async function speakBuilt(tiles,line){
  if(clipFor(line,'you'))return speak(line,'you');
  for(const t of tiles){const p=speak(t,'you');const my=TOKEN;await p;if(TOKEN!==my)return}
}
function tts(t,fin){
  if(!('speechSynthesis' in window)){fin&&fin();return}
  const u=new SpeechSynthesisUtterance(t);u.lang='ko-KR';if(VOICE)u.voice=VOICE; // other languages: pick by line lang once they exist
  if(fin){u.onend=fin;u.onerror=fin}u.rate=S.set.slow?.62:.88;speechSynthesis.speak(u);
}

/* ---------- sound effects & vibration (synthesized, no files) ---------- */
let AC=null;
function ac(){if(!AC){try{AC=new(window.AudioContext||window.webkitAudioContext)()}catch(e){return null}}if(AC.state==='suspended')AC.resume();return AC}
function tone(f,t0,dur,type='triangle',vol=.12){const c=ac();if(!c)return;const o=c.createOscillator(),g=c.createGain(),t=c.currentTime+t0;
  o.type=type;o.frequency.value=f;g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(vol,t+.008);g.gain.exponentialRampToValueAtTime(.0001,t+dur);
  o.connect(g).connect(c.destination);o.start(t);o.stop(t+dur+.05)}
function noise(t0,dur,vol,freq){const c=ac();if(!c)return;const len=Math.floor(c.sampleRate*dur),b=c.createBuffer(1,len,c.sampleRate),d=b.getChannelData(0);
  for(let i=0;i<len;i++)d[i]=(Math.random()*2-1)*(1-i/len);const s=c.createBufferSource(),f=c.createBiquadFilter(),g=c.createGain(),t=c.currentTime+t0;
  s.buffer=b;f.type='bandpass';f.frequency.value=freq;f.Q.value=.8;g.gain.value=vol;s.connect(f).connect(g).connect(c.destination);s.start(t)}
const SFX={
  tap:()=>{tone(1400,0,.045,'sine',.05);noise(0,.025,.05,2600)},
  page:()=>noise(0,.16,.05,1600),
  open:()=>noise(0,.1,.04,900),
  learn:()=>{tone(784,0,.55,'triangle',.1);tone(1175,.09,.7,'triangle',.08)},
  solve:()=>[523,659,784,1047].forEach((f,i)=>tone(f,i*.08,.8,'triangle',.08)),
  wrong:()=>tone(140,0,.22,'sine',.12),
  rewind:()=>{const c=ac();if(!c)return;const o=c.createOscillator(),g=c.createGain(),t=c.currentTime;o.type='sawtooth';
    o.frequency.setValueAtTime(900,t);o.frequency.exponentialRampToValueAtTime(180,t+.5);g.gain.setValueAtTime(.04,t);g.gain.exponentialRampToValueAtTime(.0001,t+.55);
    o.connect(g).connect(c.destination);o.start(t);o.stop(t+.6)}
};
function sfx(n){if(!S.set.sound)return;try{SFX[n]&&SFX[n]()}catch(e){}}
function buzz(p){if(S.set.sound&&navigator.vibrate)try{navigator.vibrate(p)}catch(e){}}
