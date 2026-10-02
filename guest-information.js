'use strict';
const sb=supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
const $=id=>document.getElementById(id), fields=['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone'];
const token=new URLSearchParams(location.hash.slice(1)).get('token');
history.replaceState(null,'',location.pathname);
async function boot(){
 const {data,error}=await sb.rpc('guest_information',{p_token:token});
 if(error){$('message').textContent='This link is invalid, expired, revoked, or already used. Ask Dallas THC for a new information link.';return}
 fields.forEach(key=>{$(key).value=data.info?.[key]||''});$('title').textContent='Guest information for '+data.name;
 $('message').textContent='';$('informationForm').hidden=false;
}
$('informationForm').onsubmit=async event=>{
 event.preventDefault();if($('submitInfo').disabled)return;
 const info=Object.fromEntries(fields.map(key=>[key,$(key).value.trim()]));
 $('submitInfo').disabled=true;$('formMessage').textContent='Submitting…';
 try{
  const {error}=await sb.rpc('submit_guest_information',{p_token:token,p_info:info});if(error)throw error;
  $('informationForm').hidden=true;$('success').hidden=false;
 }catch(error){$('formMessage').textContent=error.message||'Unable to submit. Please try again.';$('submitInfo').disabled=false}
};
boot().catch(()=>{$('message').textContent='Unable to check this link. Please reopen your original link and try again.'});
