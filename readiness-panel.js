/* Standalone panel demo. Replace localStorage with authenticated API calls for club use.
   The visual admin role toggle is never an authorization boundary. */
(() => {
  'use strict';
  const root = document.querySelector('#readiness-panel');
  if (!root) return;
  const $ = id => document.getElementById(id);
  const key = 'dallas-thc-readiness-demo-v1';
  const validSizes = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL'];
  const examples = [
    {id:'sample-a',name:'Sample Player A',number:'12',events:['USATH Club Nationals 2026','Regional Qualifier'],signedAt:'2026-09-01T17:40:00.000Z',dues:true,info:true,size:'M'},
    {id:'sample-b',name:'Sample Player B',number:'7',events:['USATH Club Nationals 2026'],signedAt:null,dues:true,info:true,size:'L'},
    {id:'sample-c',name:'Sample Player C',number:'',events:['Regional Qualifier'],signedAt:null,dues:false,info:false,size:''}
  ];
  const initial = {waiver:null,name:'',email:'',phone:'',position:'',dues:false,size:'',number:'',signedAt:null,signatureData:null,events:['USATH Club Nationals 2026','Regional Qualifier']};
  let saved = {};
  try { saved = JSON.parse(localStorage.getItem(key) || '{}') || {}; } catch { saved = {}; }
  const state = {...initial,...saved};
  if (!state.waiver || !/^https:\/\//i.test(state.waiver.url)) state.waiver = null;
  const isAdmin = root.dataset.role === 'admin';
  if (state.waiver) { $('waiver-name').value=state.waiver.name; $('waiver-link').value=state.waiver.url; }
  for (const [id,field] of [['player-name','name'],['player-email','email'],['player-phone','phone'],['player-position','position'],['jersey-size','size'],['player-number','number']]) $(id).value=state[field] || '';
  $('dues-verified').checked=!!state.dues;
  const sponsorUrl = root.dataset.sponsorUrl?.trim();
  if (sponsorUrl && /^https:\/\//i.test(sponsorUrl)) {
    $('sponsor-link').href=sponsorUrl; $('sponsor-link').removeAttribute('aria-disabled'); $('sponsor-note').hidden=true;
  } else $('sponsor-link').addEventListener('click',e=>e.preventDefault());
  function save() {
    try { localStorage.setItem(key,JSON.stringify(state)); return true; }
    catch { $('signature-message').textContent='Unable to save on this device. Check available browser storage.'; return false; }
  }
  const date = iso => new Date(iso).toLocaleDateString('en-US',{month:'2-digit',day:'2-digit',year:'numeric'});
  const numberOK = value => /^(?:[1-9]|[1-9][0-9])$/.test(String(value));
  const signed = p => !!(p.signedAt && (p.id!=='current' || (p.signatureData && p.waiver && p.signatureVersion === p.waiver.url)));
  const infoComplete = p => p.id==='current' ? !!(p.name.trim() && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p.email.trim()) && p.phone.trim() && p.position.trim()) : p.info;
  const ready = p => !!(signed(p) && infoComplete(p) && p.dues && validSizes.includes(p.size) && numberOK(p.number));
  const current = () => ({...state,id:'current',name:state.name.trim()||'Current player'});
  function pill(node,complete,labelWhenTrue,labelWhenFalse) {
    node.textContent=complete?labelWhenTrue:labelWhenFalse;
    node.classList.toggle('complete',complete);node.classList.toggle('pending',!complete);
  }
  function cell(row,content) { const td=document.createElement('td'); if(content instanceof Node)td.append(content);else td.textContent=content;row.append(td);return td; }
  function renderTable() {
    const event=$('event-selector').value;
    const players=[current(),...examples].filter(p=>p.events.includes(event));
    $('confirmed-count').textContent=String(players.length);
    $('signed-count').textContent=String(players.filter(signed).length);
    $('ready-count').textContent=String(players.filter(ready).length);
    const body=$('attendees-body');body.replaceChildren();
    for(const p of players){
      const row=document.createElement('tr');
      cell(row,`${p.name} · ${numberOK(p.number)?'#'+p.number:'#—'}`);
      cell(row,event);cell(row,'Going');
      cell(row,signed(p)?'Signed on '+date(p.signedAt):'Pending Signature');
      cell(row,p.dues?'Verified':'Not Verified');
      const clearance=document.createElement('span');clearance.className='status-pill '+(ready(p)?'complete':'pending');clearance.textContent=ready(p)?'READY':'NEEDS ITEMS';cell(row,clearance);
      const action=document.createElement('button');action.type='button';action.className='table-action';action.textContent='View Details';action.setAttribute('aria-label','View details for '+p.name);
      action.onclick=()=>{
        const panel=$('attendee-details');panel.replaceChildren();
        const h=document.createElement('h3');h.textContent=p.name+' · '+event;
        const t=document.createElement('p');t.textContent=`RSVP: Going · Waiver: ${signed(p)?'Signed on '+date(p.signedAt):'Pending Signature'} · Dues: ${p.dues?'Verified':'Not Verified'} · Practice: ${ready(p)?'READY':'NEEDS ITEMS'}`;
        panel.append(h,t);panel.hidden=false;panel.focus();
      };
      cell(row,action);body.append(row);
    }
  }
  function render(){
    const p=current(),isSigned=signed(p),complete=ready(p),numberValid=numberOK(state.number);
    $('selected-player').textContent='Current player: '+p.name;
    $('waiver-description').textContent=state.waiver?'Published: '+state.waiver.name:'The club will publish a waiver for signing.';
    const doc=$('read-waiver'); doc.hidden=!state.waiver;
    if(state.waiver){doc.href=state.waiver.url;doc.textContent='Read '+state.waiver.name+' ↗';$('modal-waiver-link').href=state.waiver.url;}
    $('open-signature').disabled=!state.waiver;
    pill($('waiver-status'),isSigned,'Signed','Pending Signature');
    $('signature-audit').textContent=isSigned?'Signed on '+date(state.signedAt)+' at '+new Date(state.signedAt).toLocaleTimeString('en-US',{hour:'numeric',minute:'2-digit'}):'No signature on record';
    pill($('info-status'),infoComplete(p),'Complete','Incomplete');
    pill($('dues-status'),!!state.dues,'Verified','Not Verified');
    pill($('kit-status'),validSizes.includes(state.size)&&numberValid,'Complete','Needs Items');
    $('number-message').textContent=state.number&&!numberValid?'Enter an assigned number from 1 to 99.':'';
    $('overall-badge').textContent=complete?'PRACTICE READY':'NEEDS ACTION';
    $('overall-badge').className='badge '+(complete?'complete':'attention');
    renderTable();
  }
  for(const [id,field] of [['player-name','name'],['player-email','email'],['player-phone','phone'],['player-position','position'],['jersey-size','size'],['player-number','number']]){
    $(id).addEventListener(id==='jersey-size'?'change':'input',e=>{state[field]=e.target.value;save();render();});
  }
  $('dues-verified').addEventListener('change',e=>{if(!isAdmin)return;state.dues=e.target.checked;save();render();});
  $('publish-waiver').onclick=()=>{
    if(!isAdmin)return;
    const name=$('waiver-name').value.trim(),raw=$('waiver-link').value.trim(),message=$('publish-message');
    let url;try{url=new URL(raw);}catch{url=null;}
    if(!name || !url || url.protocol!=='https:'){message.textContent='Enter a document name and a valid HTTPS link.';return;}
    const changed=state.waiver?.url!==url.href;
    state.waiver={name,url:url.href,publishedAt:new Date().toISOString()};
    if(changed){state.signedAt=null;state.signatureData=null;state.signatureVersion=null;}
    if(save()){message.textContent='Waiver published. Players can now open and sign it.';render();}
  };
  const modal=$('signature-modal'),canvas=$('signature-canvas'),context=canvas.getContext('2d');
  let drawing=false,hasInk=false,returnFocus=null;
  function prepareCanvas(){
    const rect=canvas.getBoundingClientRect(),ratio=window.devicePixelRatio||1;
    canvas.width=Math.max(1,Math.round(rect.width*ratio));canvas.height=Math.max(1,Math.round(rect.height*ratio));
    context.setTransform(ratio,0,0,ratio,0,0);context.lineWidth=2.5;context.lineCap='round';context.lineJoin='round';context.strokeStyle='#103b21';
    context.fillStyle='#f7fbf7';context.fillRect(0,0,rect.width,rect.height);hasInk=false;
  }
  const point=e=>{const r=canvas.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};};
  canvas.addEventListener('pointerdown',e=>{
    if(!state.waiver)return;
    drawing=true;canvas.setPointerCapture(e.pointerId);const p=point(e);
    context.beginPath();context.moveTo(p.x,p.y);context.lineTo(p.x+.05,p.y+.05);context.stroke();hasInk=true;
  });
  canvas.addEventListener('pointermove',e=>{if(!drawing)return;const p=point(e);context.lineTo(p.x,p.y);context.stroke();});
  for(const type of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(type,()=>{drawing=false;});
  $('open-signature').onclick=()=>{
    if(!state.waiver)return;
    returnFocus=document.activeElement;modal.hidden=false;document.body.style.overflow='hidden';
    $('read-confirmation').checked=false;$('signature-message').textContent='';
    requestAnimationFrame(()=>{prepareCanvas();$('close-signature').focus();});
  };
  function close(){modal.hidden=true;document.body.style.overflow='';returnFocus?.focus();}
  $('close-signature').onclick=close;
  modal.addEventListener('pointerdown',e=>{if(e.target===modal)close();});
  document.addEventListener('keydown',e=>{
    if(modal.hidden)return;
    if(e.key==='Escape'){close();return;}
    if(e.key==='Tab'){
      const controls=[...modal.querySelectorAll('a,button,input')].filter(el=>!el.disabled);
      if(e.shiftKey&&document.activeElement===controls[0]){e.preventDefault();controls.at(-1).focus();}
      else if(!e.shiftKey&&document.activeElement===controls.at(-1)){e.preventDefault();controls[0].focus();}
    }
  });
  $('clear-signature').onclick=prepareCanvas;
  $('submit-signature').onclick=()=>{
    const message=$('signature-message');
    if(!state.waiver){message.textContent='The waiver is no longer available.';return;}
    if(!hasInk){message.textContent='Draw your signature before submitting.';return;}
    if(!$('read-confirmation').checked){message.textContent='Confirm that you read the waiver first.';return;}
    const prior={signatureData:state.signatureData,signedAt:state.signedAt,signatureVersion:state.signatureVersion};
    state.signatureData=canvas.toDataURL('image/png');
    state.signedAt=new Date().toISOString();state.signatureVersion=state.waiver.url;
    if(save()){close();render();}
    else Object.assign(state,prior);
  };
  $('event-selector').onchange=()=>{$('attendee-details').hidden=true;renderTable();};
  render();
  window.ReadinessPanel={
    // Trusted host app can supply its verified role and sponsor URL before initialization.
    snapshot:()=>JSON.parse(JSON.stringify(state)),practiceReady:()=>ready(current())
  };
})();
