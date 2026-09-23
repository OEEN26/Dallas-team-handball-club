const sb = supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
const $ = id => document.getElementById(id);
let awards = [], grants = [], history = [], players = [], people = new Map(), editingId = null, previewUrl = null;
const imageUrl = path => path ? sb.storage.from('award-media').getPublicUrl(path).data.publicUrl : '';
const label = (id,map) => map.get(id) || 'Former member';
function notice(id,message,error=false){$(id).textContent=message;$(id).classList.toggle('error',error)}
function badgeImage(award){if(award.image_path){const image=document.createElement('img');image.src=imageUrl(award.image_path);image.alt='';return image}const fallback=document.createElement('span');fallback.className='fallback';fallback.setAttribute('aria-hidden','true');fallback.textContent='🏅';return fallback}
function createButton(name,click,style=''){const button=document.createElement('button');button.type='button';button.className='btn '+style;button.textContent=name;button.addEventListener('click',click);return button}
async function boot(){
  const {data:{session},error:authError}=await sb.auth.getSession();
  if(authError||!session){$('pageStatus').textContent='Sign in as an admin to manage awards.';return}
  const {data:profile,error:roleError}=await sb.from('profiles').select('role').eq('id',session.user.id).maybeSingle();
  if(roleError||profile?.role!=='admin'){$('pageStatus').textContent='Admin access is required to manage awards.';return}
  $('panel').hidden=false;await loadAll();
}
async function loadAll(){
  $('pageStatus').textContent='Loading awards…';
  const [a,g,h,p,pr]=await Promise.all([
    sb.from('award_definitions').select('id,title,description,image_path,is_active,created_at,updated_at').order('created_at',{ascending:false}),
    sb.from('award_grants').select('id,award_id,player_id,granted_at,granted_by,revoked_at,revoked_by'),
    sb.from('award_history').select('id,award_id,player_id,action,actor_id,happened_at').order('happened_at',{ascending:false}).limit(100),
    sb.from('players').select('id,name,team,status').is('deleted_at',null).order('name'),
    sb.from('profiles').select('id,full_name')
  ]);
  const failed=[a,g,h,p,pr].find(result=>result.error);
  if(failed){$('pageStatus').textContent='Could not load awards: '+failed.error.message;return}
  awards=a.data||[];grants=g.data||[];history=h.data||[];players=p.data||[];
  people=new Map((pr.data||[]).map(row=>[row.id,row.full_name||'Admin']));
  $('pageStatus').textContent='Season medals are automatic. Custom awards are managed here.';
  render();
}
function render(){
  $('awardCount').textContent=awards.length+' award'+(awards.length===1?'':'s');
  const active=grants.filter(x=>!x.revoked_at&&awards.some(a=>a.id===x.award_id&&a.is_active)).length;
  $('grantCount').textContent=active+' active player award'+(active===1?'':'s');
  renderCatalog();renderPicker();renderPlayers();renderRoster();renderHistory();
}
function renderCatalog(){
  const list=$('awardsList');list.replaceChildren();
  if(!awards.length){list.innerHTML='<div class="empty">No custom awards yet. Create the first one here.</div>';return}
  for(const award of awards){
    const card=document.createElement('article');card.className='award-card';
    const body=document.createElement('div');body.className='body';
    const title=document.createElement('strong');title.textContent=award.title;
    const state=document.createElement('span');state.className='tag'+(award.is_active?'':' off');state.textContent=award.is_active?'Active':'Archived';state.style.marginLeft='8px';
    const description=document.createElement('p');description.textContent=award.description;
    const count=document.createElement('span');count.className='muted small';count.textContent=grants.filter(g=>g.award_id===award.id&&!g.revoked_at).length+' players awarded';
    const actions=document.createElement('div');actions.className='actions';
    actions.append(createButton('Edit',()=>editAward(award)));
    actions.append(createButton(award.is_active?'Archive':'Restore',()=>setAwardState(award,!award.is_active),award.is_active?'danger':''));
    body.append(title,state,description,count,actions);card.append(badgeImage(award),body);list.append(card);
  }
}
function renderPicker(){
  const picker=$('awardPicker'),selected=picker.value;
  picker.replaceChildren();
  for(const award of awards.filter(a=>a.is_active))picker.add(new Option(award.title,award.id));
  if(awards.some(a=>a.id===selected&&a.is_active))picker.value=selected;
  $('grantAward').disabled=!picker.value;
  $('rosterHint').textContent=picker.value?'You can revoke an award given in error. History keeps a record.':'Create an active award to start recognizing players.';
}
function renderPlayers(){
  const picker=$('playerPicker'),selected=picker.value,term=$('playerSearch').value.trim().toLowerCase(),team=$('teamFilter').value;
  picker.replaceChildren();
  for(const player of players.filter(p=>(team==='All'||p.team===team)&&(!term||p.name.toLowerCase().includes(term))))picker.add(new Option(player.name+' · '+(player.team||'Team'),player.id));
  if(players.some(p=>p.id===selected))picker.value=selected;
  $('grantAward').disabled=!picker.value||!$('awardPicker').value;
}
function renderRoster(){
  const id=$('awardPicker').value,list=$('awardedPlayers');list.replaceChildren();
  const rows=grants.filter(g=>g.award_id===id).sort((a,b)=>(a.revoked_at?1:0)-(b.revoked_at?1:0)||new Date(b.granted_at)-new Date(a.granted_at));
  if(!rows.length){list.innerHTML='<div class="empty">Nobody has this award yet.</div>';return}
  for(const grant of rows){
    const row=document.createElement('div');row.className='entry';
    const copy=document.createElement('div'),name=document.createElement('strong'),meta=document.createElement('span');
    name.textContent=players.find(p=>p.id===grant.player_id)?.name||'Former player';meta.className='muted';
    meta.textContent=(grant.revoked_at?'Revoked':'Awarded')+' · '+new Date(grant.revoked_at||grant.granted_at).toLocaleDateString();
    copy.append(name,meta);
    row.append(copy,createButton(grant.revoked_at?'Reaward':'Revoke',()=>changeGrant(grant,!!grant.revoked_at),grant.revoked_at?'':'danger'));
    list.append(row);
  }
}
function renderHistory(){
  const list=$('historyList');list.replaceChildren();
  if(!history.length){list.innerHTML='<div class="empty">Award changes will appear here.</div>';return}
  for(const item of history){
    const award=awards.find(a=>a.id===item.award_id),player=players.find(p=>p.id===item.player_id);
    const row=document.createElement('div');row.className='entry history-entry';
    const text=document.createElement('div'),headline=document.createElement('strong'),meta=document.createElement('p'),time=document.createElement('time');
    headline.textContent=(item.action[0].toUpperCase()+item.action.slice(1))+' · '+(award?.title||'Former award');
    meta.className='muted';meta.textContent=(player?.name?player.name+' · ':'')+'By '+label(item.actor_id,people);
    time.textContent=new Date(item.happened_at).toLocaleString();text.append(headline,meta);row.append(text,time);list.append(row);
  }
}
function showPreview(url){const image=$('imagePreview');image.hidden=!url;if(url)image.src=url;else image.removeAttribute('src')}
function editAward(award){
  editingId=award.id;$('formTitle').textContent='Edit '+award.title;$('awardTitle').value=award.title;$('awardDescription').value=award.description;$('awardImage').value='';
  showPreview(imageUrl(award.image_path));$('saveAward').textContent='Save changes';$('cancelEdit').hidden=false;notice('awardMessage','');$('awardForm').scrollIntoView({behavior:'smooth',block:'start'});
}
function clearEdit(){editingId=null;$('awardForm').reset();$('formTitle').textContent='Create an award';$('saveAward').textContent='Create award';$('cancelEdit').hidden=true;showPreview('');notice('awardMessage','')}
$('cancelEdit').onclick=clearEdit;
$('awardImage').onchange=()=>{if(previewUrl)URL.revokeObjectURL(previewUrl);const file=$('awardImage').files[0];previewUrl=file?URL.createObjectURL(file):null;showPreview(previewUrl||(editingId?imageUrl(awards.find(a=>a.id===editingId)?.image_path):''))};
$('awardForm').onsubmit=async event=>{
  event.preventDefault();const button=$('saveAward');button.disabled=true;notice('awardMessage','Saving award…');
  try{
    const file=$('awardImage').files[0],payload={title:$('awardTitle').value.trim(),description:$('awardDescription').value.trim()};
    if(file){
      const ext=({'image/png':'png','image/jpeg':'jpg','image/webp':'webp'})[file.type];
      if(!ext||file.size>2097152)throw new Error('Choose a PNG, JPG, or WebP image no larger than 2 MB.');
      payload.image_path='awards/'+crypto.randomUUID()+'.'+ext;
      const {error:uploadError}=await sb.storage.from('award-media').upload(payload.image_path,file,{contentType:file.type,upsert:false});
      if(uploadError)throw uploadError;
    }
    const result=editingId?await sb.from('award_definitions').update(payload).eq('id',editingId).select('id').single():await sb.from('award_definitions').insert(payload).select('id').single();
    if(result.error)throw result.error;
    clearEdit();await loadAll();notice('awardMessage','Award saved.');
  }catch(error){notice('awardMessage',error.message||'Could not save award.',true)}finally{button.disabled=false}
};
async function setAwardState(award,active){
  if(!active&&!confirm('Archive '+award.title+'? It will disappear from player profiles until restored. Award history remains.'))return;
  const {error}=await sb.from('award_definitions').update({is_active:active}).eq('id',award.id).select('id').single();
  if(error){notice('awardMessage',error.message,true);return}if(editingId===award.id)clearEdit();await loadAll();notice('awardMessage',active?'Award restored.':'Award archived.');
}
$('awardPicker').onchange=()=>{renderRoster();renderPlayers();notice('grantMessage','')};
$('teamFilter').onchange=renderPlayers;$('playerSearch').oninput=renderPlayers;
$('grantAward').onclick=async()=>{
  const awardId=$('awardPicker').value,playerId=$('playerPicker').value,award=awards.find(a=>a.id===awardId),player=players.find(p=>p.id===playerId);
  if(!award?.is_active||!player)return;
  const existing=grants.find(g=>g.award_id===awardId&&g.player_id===playerId);
  if(existing&&!existing.revoked_at){notice('grantMessage',player.name+' already has this award.');return}
  $('grantAward').disabled=true;notice('grantMessage','Awarding…');
  const result=existing?await sb.from('award_grants').update({revoked_at:null}).eq('id',existing.id).select('id').single():await sb.from('award_grants').insert({award_id:awardId,player_id:playerId}).select('id').single();
  $('grantAward').disabled=false;
  if(result.error){notice('grantMessage',result.error.message,true);return}
  await loadAll();notice('grantMessage','Awarded '+award.title+' to '+player.name+'.');
};
async function changeGrant(grant,restore){
  const player=players.find(p=>p.id===grant.player_id),award=awards.find(a=>a.id===grant.award_id);
  if(!restore&&!confirm('Revoke '+(award?.title||'this award')+' from '+(player?.name||'this player')+'? The change will remain in award history.'))return;
  const {error}=await sb.from('award_grants').update({revoked_at:restore?null:new Date().toISOString()}).eq('id',grant.id).select('id').single();
  if(error){notice('grantMessage',error.message,true);return}await loadAll();notice('grantMessage',restore?'Award restored to player.':'Award revoked; history kept.');
}
boot().catch(error=>{$('pageStatus').textContent=error.message||'Could not load awards.'});
