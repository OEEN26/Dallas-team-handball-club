'use strict';
const sb=supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
const $=id=>document.getElementById(id),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fields=['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone','instagram','facebook','tiktok','profile_photo'];
const photoEditor=GuestMedia.editor();
let players=[],details=new Map(),editing=null;
async function rpc(name,args){const {data,error}=await sb.rpc(name,args);if(error)throw error;return data}
async function boot(){
 const {data:{session}}=await sb.auth.getSession();if(!session){location.href='./index.html';return}
 const {data:profile,error}=await sb.from('profiles').select('role').eq('id',session.user.id).maybeSingle();
 if(error||!['admin','manager'].includes(profile?.role)){location.href='./player-dashboard.html';return}
 $('addGuest').disabled=false;$('createRegistrationLink').disabled=false;
 await load();
 const requested=new URLSearchParams(location.search).get('id');if(requested&&players.some(p=>p.id===requested))await openGuest(requested);
}
async function load(){
 const [p,d,s]=await Promise.all([sb.from('players').select('id,name,team,position,shirt_size,player_category').eq('player_category','Guest').is('deleted_at',null).order('name'),sb.from('guest_details').select('*'),sb.from('guest_submissions').select('player_id').eq('status','Pending')]);
 if(p.error||d.error||s.error)throw p.error||d.error||s.error;
 players=(p.data||[]).map(p=>({...p,pending:(s.data||[]).filter(s=>s.player_id===p.id).length}));details=new Map((d.data||[]).map(d=>[d.player_id,d]));
 $('directory').hidden=false;$('message').textContent=players.length+' guest players';render();
 try{await loadRegistrations()}catch(e){$('registrationSection').hidden=false;$('registrations').textContent='Unable to load registrations: '+e.message;}
}
function render(){const q=$('search').value.trim().toLowerCase();const rows=players.filter(p=>{const d=details.get(p.id);return !q||[p.name,p.team,d?.info?.home_club,d?.uniform_number].some(v=>String(v??'').toLowerCase().includes(q))});
 $('list').innerHTML=rows.map(p=>{const d=details.get(p.id);return '<article class="card"><div class="row"><div class="guest-summary">'+GuestMedia.avatar({...d?.info,name:p.name})+'<div><h2>'+esc(p.name)+'</h2><span class="badge">Guest</span> <span class="muted">'+esc(d?.info?.home_club||'Home club not recorded')+' • '+esc(p.team)+' • '+esc(p.position||'Position not recorded')+'</span></div></div><button class="btn" data-edit="'+p.id+'">Edit guest</button></div><p>'+esc(d?.uniform_ownership||'None')+' uniform'+(d?.uniform_number?' • #'+esc(d.uniform_number):'')+(d?.uniform_size?' • '+esc(d.uniform_size):'')+(d?.uniform_return_status==='Return pending'?' • Return pending':'')+'</p>'+(p.pending?'<span class="badge">'+p.pending+' information submission'+(p.pending===1?'':'s')+' to review</span>':'')+'</article>'}).join('')||'<div class="card">No guests match. Add a guest or mark an existing player as a guest from Club Members.</div>';
}
async function openGuest(id){
 editing=id||null;const p=players.find(p=>p.id===id),d=details.get(id),info=d?.info||{name:p?.name,team:p?.team,position:p?.position,shirt_size:p?.shirt_size};
 fields.forEach(key=>{$(key).value=info[key]||''});photoEditor.reset();if(!$('team').value)$('team').value='Men';
 $('uniform_number').value=d?.uniform_number??'';$('uniform_size').value=d?.uniform_size||'';$('uniform_ownership').value=d?.uniform_ownership||'None';$('uniform_return').value=d?.uniform_return_status||'Not applicable';$('notes').value=d?.admin_notes||'';
 $('editTitle').textContent=id?'Edit '+p.name:'Add guest';$('existing').hidden=!id;$('editMessage').textContent='';$('linkbox').hidden=true;$('linkStatus').textContent='';
 if(!$('editor').open)$('editor').showModal();if(id)await loadRecord(id);
}
async function loadRecord(id){
 const [s,t,h,l]=await Promise.all([sb.from('guest_submissions').select('*').eq('player_id',id).eq('status','Pending').order('submitted_at',{ascending:false}),sb.from('tournament_players').select('roster_status,jersey_number,tournaments(id,title,start_date)').eq('player_id',id).order('created_at',{ascending:false}),sb.from('guest_edit_history').select('action,changed_by,changed_at').eq('player_id',id).order('changed_at',{ascending:false}).limit(20),rpc('admin_guest_links',{p_player_id:id,p_revoke:false})]);
 if(s.error||t.error||h.error)throw s.error||t.error||h.error;if(editing!==id)return;
 const actorIds=[...new Set((h.data||[]).map(r=>r.changed_by).filter(Boolean))];const actors=actorIds.length?await sb.from('profiles').select('id,full_name').in('id',actorIds):{data:[]};const names=new Map((actors.data||[]).map(p=>[p.id,p.full_name]));
 $('editHistory').innerHTML=(h.data||[]).map(r=>'<div class="history">'+esc(r.action)+' • '+esc(names.get(r.changed_by)||'Club admin')+'<div class="muted">'+esc(new Date(r.changed_at).toLocaleString())+'</div></div>').join('')||'<p class="muted">No changes recorded yet.</p>';
 $('tournamentHistory').innerHTML=(t.data||[]).map(r=>'<div class="history"><b>'+esc(r.tournaments?.title||'Tournament')+'</b> • '+esc(r.roster_status)+(r.jersey_number?' • #'+esc(r.jersey_number):'')+'<div class="muted">'+esc(r.tournaments?.start_date||'Date not set')+'</div></div>').join('')||'<p class="muted">No tournaments recorded yet.</p>';
 const current=details.get(id)?.info||{};
 $('submissions').innerHTML=(s.data||[]).map(r=>'<article class="card"><p class="muted">Submitted '+esc(new Date(r.submitted_at).toLocaleString())+'</p><table class="table"><thead><tr><th>Detail</th><th>Current</th><th>Submitted</th></tr></thead><tbody>'+fields.map(k=>'<tr><th>'+esc(GuestMedia.labels[k]||'Profile photo')+'</th><td>'+GuestMedia.detail(k,current[k])+'</td><td>'+GuestMedia.detail(k,r.info[k])+'</td></tr>').join('')+'</tbody></table><div class="actions"><button class="btn primary" data-review="'+r.id+'" data-approve="true">Approve changes</button><button class="btn" data-review="'+r.id+'" data-approve="false">Reject changes</button></div></article>').join('')||'<p class="muted">No information is waiting for review.</p>';
 const latest=l[0];$('linkStatus').textContent=latest?(latest.revoked_at?'Latest link revoked.':latest.used_at?'Latest link submitted.':Date.parse(latest.expires_at)<=Date.now()?'Latest link expired.':'Link expires '+new Date(latest.expires_at).toLocaleString()):'No link created yet.';
}
$('guestForm').onsubmit=async event=>{event.preventDefault();if(photoEditor.busy()){$('editMessage').textContent='Please wait for the photo to finish preparing.';return}const button=$('saveGuest');if(button.disabled)return;button.disabled=true;$('editMessage').textContent='Saving…';
 try{const id=await rpc('admin_save_guest',{p_player_id:editing,p_info:Object.fromEntries(fields.map(k=>[k,$(k).value.trim()])),p_uniform:{number:$('uniform_number').value,size:$('uniform_size').value,ownership:$('uniform_ownership').value,return_status:$('uniform_return').value},p_notes:$('notes').value.trim()});await load();await openGuest(id);$('editMessage').textContent='Guest record saved.'}catch(e){$('editMessage').textContent=e.message}finally{button.disabled=false}};
$('createLink').onclick=async()=>{const button=$('createLink');button.disabled=true;try{const link=await rpc('admin_create_guest_link',{p_player_id:editing});$('linkInput').value=new URL('guest-information.html',location.href).href+'#token='+link.token;$('linkbox').hidden=false;$('linkStatus').textContent='Expires '+new Date(link.expires_at).toLocaleString()+'. Copy and send it to this guest.'}catch(e){$('linkStatus').textContent=e.message}finally{button.disabled=false}};
$('copyLink').onclick=async()=>{try{await navigator.clipboard.writeText($('linkInput').value);$('linkStatus').textContent='Link copied. Send it to this guest.'}catch{ $('linkInput').select();$('linkStatus').textContent='Select and copy the link above.'}};
$('revokeLinks').onclick=async()=>{try{await rpc('admin_guest_links',{p_player_id:editing,p_revoke:true});$('linkbox').hidden=true;$('linkInput').value='';$('linkStatus').textContent='Links revoked.'}catch(e){$('linkStatus').textContent=e.message}};
$('submissions').onclick=async event=>{const b=event.target.closest('[data-review]');if(!b)return;if(b.dataset.approve==='true'&&!confirm('Apply these submitted details to this guest profile? Uniform and private admin notes will stay as saved.'))return;b.disabled=true;try{await rpc('admin_review_guest_submission',{p_submission_id:b.dataset.review,p_approve:b.dataset.approve==='true'});await load();await openGuest(editing)}catch(e){$('editMessage').textContent=e.message;b.disabled=false}};
$('convertMember').onclick=async()=>{if(!confirm('Convert this guest into a club member? Their tournament history will be kept. Season approval and a club jersey assignment are handled separately.'))return;try{await rpc('admin_classify_player',{p_player_id:editing,p_category:'Member'});$('editor').close();await load();$('message').textContent='Converted to club member. Open Club Members to manage season eligibility.'}catch(e){$('editMessage').textContent=e.message}};
$('list').onclick=event=>{const b=event.target.closest('[data-edit]');if(b)openGuest(b.dataset.edit).catch(e=>{$('editMessage').textContent=e.message})};
$('addGuest').onclick=()=>openGuest(null);$('closeEditor').onclick=()=>{$('editor').close();editing=null};$('search').oninput=render;
boot().catch(e=>{$('message').textContent='Unable to load guests: '+e.message});

async function loadRegistrations(){
 const {data,error}=await sb.from('guest_registrations').select('id,info,submitted_at').eq('status','Pending').order('submitted_at',{ascending:false});if(error)throw error;
 $('registrationSection').hidden=!data?.length;
 $('registrations').innerHTML=(data||[]).map(r=>'<article class="card registration-card"><details><summary><span class="guest-summary">'+GuestMedia.avatar(r.info)+'<span class="guest-summary-text"><strong>'+esc(r.info.name)+'</strong><span class="muted">'+esc([r.info.team,r.info.position].filter(Boolean).join(' • '))+'</span><span class="badge">Pending review</span></span></span><span class="detail-toggle"><span class="when-closed">View details</span><span class="when-open">Hide details</span> <span aria-hidden="true">⌄</span></span></summary><div class="registration-details"><p class="muted">Submitted '+esc(new Date(r.submitted_at).toLocaleString())+'</p><h3>Player details</h3><dl class="detail-grid">'+['home_club','shirt_size','email','phone'].map(k=>'<div><dt>'+esc(GuestMedia.labels[k])+'</dt><dd>'+GuestMedia.detail(k,r.info[k])+'</dd></div>').join('')+'</dl><h3>Emergency contact</h3><dl class="detail-grid">'+['emergency_name','emergency_phone'].map(k=>'<div><dt>'+esc(GuestMedia.labels[k])+'</dt><dd>'+GuestMedia.detail(k,r.info[k])+'</dd></div>').join('')+'</dl>'+(['instagram','facebook','tiktok'].some(k=>r.info[k])?'<h3>Social media</h3><dl class="detail-grid">'+['instagram','facebook','tiktok'].filter(k=>r.info[k]).map(k=>'<div><dt>'+esc(GuestMedia.labels[k])+'</dt><dd>'+GuestMedia.detail(k,r.info[k])+'</dd></div>').join('')+'</dl>':'')+'<div class="actions"><button class="btn primary" data-registration="'+r.id+'" data-approve="true">Approve guest</button><button class="btn" data-registration="'+r.id+'" data-approve="false">Reject</button></div></div></details></article>').join('');

}
$('createRegistrationLink').onclick=async()=>{
 const b=$('createRegistrationLink');b.disabled=true;
 try{const link=await rpc('admin_create_guest_registration_link',{});$('registrationLinkInput').value=new URL('guest-information.html',location.href).href+'#registration=1&token='+link.token;$('registrationLinkbox').hidden=false;$('registrationLinkStatus').textContent='Send to one guest. Expires '+new Date(link.expires_at).toLocaleString()+'. Create another link for the next guest.'}catch(e){$('registrationLinkStatus').textContent=e.message}finally{b.disabled=false}
};
$('copyRegistrationLink').onclick=async()=>{try{await navigator.clipboard.writeText($('registrationLinkInput').value);$('registrationLinkStatus').textContent='Link copied. Send it to your guest.'}catch{$('registrationLinkInput').select();$('registrationLinkStatus').textContent='Select and copy the link above.'}};
$('registrations').onclick=async event=>{const b=event.target.closest('[data-registration]');if(!b)return;b.disabled=true;try{await rpc('admin_review_guest_registration',{p_registration_id:b.dataset.registration,p_approve:b.dataset.approve==='true'});await load();$('message').textContent=b.dataset.approve==='true'?'Guest approved and added to Guests.':'Registration rejected.'}catch(e){$('message').textContent=e.message;b.disabled=false}};

