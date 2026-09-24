/* Player reminders run while the club app is open. Preferences stay on this device. */
window.clubReminders = (() => {
  const categories = {practice:'Practice changes and upcoming practices',tournament:'Tournament dates and roster selection',event:'Upcoming events'};
  const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const dateText = value => new Date(value+'T12:00:00').toLocaleDateString(undefined,{month:'short',day:'numeric'});
  function daysUntil(date){return Math.ceil((new Date(date+'T12:00:00')-new Date())/86400000)}
  async function init({client,userId,playerId,team}){
    const holder=document.getElementById('reminderCenter')||document.getElementById('reminderSettings');
    if(!holder)return;
    const key='dthc-reminders-'+userId,previousKey=key+'-seen';
    let prefs={practice:true,tournament:true,event:true,device:false};
    try{prefs={...prefs,...JSON.parse(localStorage.getItem(key)||'{}')}}catch{}
    const save=()=>localStorage.setItem(key,JSON.stringify(prefs));
    holder.innerHTML='<div class="club-reminder"><h3>Reminders</h3><p>Choose which updates appear here. Device alerts work while the app is open. Your choices are saved on this device.</p><div class="club-reminder-choices">'+Object.entries(categories).map(([id,name])=>'<label><input type="checkbox" data-reminder="'+id+'" '+(prefs[id]?'checked':'')+'> '+name+'</label>').join('')+'</div><button type="button" class="club-reminder-enable">Enable device alerts</button><div class="club-reminder-status" role="status"></div><div class="club-reminder-list" aria-live="polite"></div></div>';
    const list=holder.querySelector('.club-reminder-list'),status=holder.querySelector('.club-reminder-status');
    holder.querySelectorAll('[data-reminder]').forEach(input=>input.onchange=()=>{prefs[input.dataset.reminder]=input.checked;save();render()});
    const enableButton=holder.querySelector('.club-reminder-enable');
    enableButton.textContent=prefs.device?'Turn off device alerts':'Enable device alerts';
    enableButton.onclick=async()=>{
      if(prefs.device){prefs.device=false;save();enableButton.textContent='Enable device alerts';status.textContent='Device alerts turned off.';return}
      if(!('Notification' in window)||!('serviceWorker' in navigator)){status.textContent='Device alerts are unavailable in this browser. In-app reminders remain available.';return}
      const permission=await Notification.requestPermission();prefs.device=permission==='granted';save();enableButton.textContent=prefs.device?'Turn off device alerts':'Enable device alerts';status.textContent=prefs.device?'Device alerts enabled while the app is open.':'Device alerts are off; in-app reminders remain available.';
    };
    let reminders=[];
    function render(){const visible=reminders.filter(r=>prefs[r.category]);list.innerHTML=visible.length?visible.map(r=>'<a href="'+r.url+'"><strong>'+escapeHtml(r.title)+'</strong><span>'+escapeHtml(r.detail)+'</span></a>').join(''):'<div class="club-reminder-empty">No reminders right now.</div>'}
    async function refresh(){
      const today=new Date().toISOString().slice(0,10);
      const [pr,ev,to,tp]=await Promise.all([
        client.from('practices').select('id,title,practice_date,updated_at,canceled,location,start_time').in('team',['All',team]).gte('practice_date',today).order('practice_date').limit(20),
        client.from('club_events').select('id,title,event_date').in('team',['All',team]).gte('event_date',today).order('event_date').limit(20),
        client.from('tournaments').select('id,title,start_date,status').eq('status','Open').gte('start_date',today).order('start_date').limit(20),
        client.from('tournament_players').select('tournament_id,roster_status').eq('player_id',playerId)
      ]);
      if([pr,ev,to,tp].some(x=>x.error)){status.textContent='Reminders could not refresh. Try again later.';return}
      let previous={};try{previous=JSON.parse(localStorage.getItem(previousKey)||'{}')}catch{}
      const current={},next=[],add=(category,id,title,detail,url)=>next.push({category,id,title,detail,url});
      for(const p of pr.data||[]){
        const state=[p.updated_at,p.canceled,p.location,p.start_time].join('|');current['practice:'+p.id]=state;
        const changed=previous['practice:'+p.id]&&previous['practice:'+p.id]!==state;
        if(daysUntil(p.practice_date)<=7&&(p.canceled||changed))add('practice','practice:'+p.id,p.canceled?'Practice canceled':'Practice details changed',p.title+' • '+dateText(p.practice_date),'./club-hub.html?tab=schedule');
        else if(!p.canceled&&daysUntil(p.practice_date)<=1)add('practice','practice:'+p.id,'Practice coming up',p.title+' • '+dateText(p.practice_date),'./club-hub.html?tab=schedule');
      }
      for(const e of ev.data||[])if(daysUntil(e.event_date)<=1)add('event','event:'+e.id,'Event coming up',e.title+' • '+dateText(e.event_date),'./events.html');
      const responses=new Map((tp.data||[]).map(x=>[x.tournament_id,x.roster_status]));
      for(const t of to.data||[]){const response=responses.get(t.id)||'';current['tournament:'+t.id]=response;
        if(['Selected','Confirmed'].includes(response))add('tournament','tournament:'+t.id,'Tournament roster: '+response,t.title+' • '+dateText(t.start_date),'./club-hub.html?tab=tournaments&tournament='+encodeURIComponent(t.id));
        else if(daysUntil(t.start_date)<=7&&!response)add('tournament','tournament:'+t.id,'Tournament starts soon',t.title+' • Respond if you want to go','./club-hub.html?tab=tournaments&tournament='+encodeURIComponent(t.id));
      }
      reminders=next;render();
      if(prefs.device&&typeof Notification!=='undefined'&&Notification.permission==='granted'&&Object.keys(previous).length){
        const fresh=next.filter(r=>prefs[r.category]&&current[r.id]!==previous[r.id]);
        if(fresh.length)try{const registration=await navigator.serviceWorker.ready;for(const r of fresh.slice(0,3))await registration.showNotification(r.title,{body:r.detail,tag:r.id,data:{url:r.url},icon:'./icons/icon-192.png'})}catch{}
      }
      localStorage.setItem(previousKey,JSON.stringify(current));
    }
    await refresh();const timer=setInterval(refresh,300000);window.addEventListener('pagehide',()=>clearInterval(timer),{once:true});
  }
  return {init};
})();
