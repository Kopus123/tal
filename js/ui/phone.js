/* ============ PHONE ============ */

const msgsOf=t=>t.m.filter(m=>cond(m.c));
const msgCount=t=>msgsOf(t).filter(m=>!m.d).length;
const unread=t=>(S.F['readn_'+t.id]||0)<msgCount(t);
function openPhone(){
  const o=overlay(`<div class="phone" role="dialog" aria-label="Phone"><div class="ph-status"><span>08:47</span><span>▂▄▆ 42%</span></div><div id="phv" style="flex:1;display:flex;flex-direction:column;min-height:0"></div></div>`,'center');
  const list=()=>{
    stopAudio();
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><b>메시지</b><button id="pc">Close</button></div><div class="ph-list">${ST.phones.map(t=>`<button class="thr" data-th="${t.id}"><span class="av" style="background:${t.c}">${esc(t.av)}</span><span style="min-width:0;flex:1"><div class="nm">${esc(t.name)}</div><div class="pv">${(()=>{const m=msgsOf(t).filter(m=>m.ko).pop()||{};return m.vm?'🔊 음성 메시지':esc(plain(m.ko||''))})()}</div></span>${unread(t)?'<span class="new"></span>':''}</button>`).join('')}</div>`;
    o.querySelector('#pc').onclick=()=>close(o);
    o.querySelectorAll('[data-th]').forEach(b=>b.onclick=()=>{sfx('tap');thread(ST.phones.find(t=>t.id===b.dataset.th))});
  };
  const thread=t=>{
    const before=S.F['readn_'+t.id]||0;msgsOf(t).filter(m=>!m.d).slice(before).forEach(m=>noteSeen(m.ko));
    runFx(t.fx);S.F['read_'+t.id]=1;S.F['readn_'+t.id]=msgCount(t);const ms=msgsOf(t);
    o.querySelector('#phv').innerHTML=`<div class="ph-top"><button id="pb">‹ Back</button><b>${esc(t.name)}</b></div><div class="msgs">${ms.map((m,i)=>m.d?`<div class="day">${ko(m.d)}</div>`:m.sys?`<div class="bub sys">${esc(m.ko)}</div>`:m.vm?`<button class="bub vm" data-vm="${i}"><span class="vmplay">▶</span> 음성 메시지<small>${m.t} · tap to listen</small></button>`:`<div class="bub ${m.me?'me':''}" data-bi="${i}">${ko(m.ko)}<small>${m.t} · tap to hear</small></div>`).join('')}${t.note&&cond(t.noteC)?`<div class="ph-note">${esc(t.note)}</div>`:''}</div>`;
    o.querySelectorAll('[data-bi]').forEach(b=>b.onclick=()=>speak(ms[+b.dataset.bi].ko,'sign'));
    o.querySelectorAll('[data-vm]').forEach(b=>b.onclick=()=>{const m=ms[+b.dataset.vm];S.F['vm_'+t.id]=1;speak(m.ko,m.who)});
    o.querySelector('#pb').onclick=list;save();dots();
    const mm=o.querySelector('.msgs');if(mm)mm.scrollTop=mm.scrollHeight;
  };
  list();
}
