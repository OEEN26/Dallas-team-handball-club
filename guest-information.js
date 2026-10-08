'use strict';
const sb=supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
const $=id=>document.getElementById(id), fields=['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone','instagram','facebook','tiktok','profile_photo'];
const params=new URLSearchParams(location.hash.slice(1)),token=params.get('token'),registration=params.get('registration')==='1';
history.replaceState(null,'',location.pathname);
const photoEditor=GuestMedia.editor();
async function boot(){
 const {data,error}=await sb.rpc(registration?'guest_registration_information':'guest_information',{p_token:token});
 if(error){$('message').textContent='This link is invalid, expired, revoked, or already used. Ask Dallas THC for a new information link.';return}
 fields.forEach(key=>{$(key).value=data.info?.[key]||''});$('title').textContent=registration?'Guest player registration':'Guest information for '+data.name;
 photoEditor.reset();$('message').textContent='';$('informationForm').hidden=false;
}
$('informationForm').onsubmit=async event=>{
 event.preventDefault();if($('submitInfo').disabled)return;if(photoEditor.busy()){$('formMessage').textContent='Please wait for your photo to finish preparing.';return}
 const info=Object.fromEntries(fields.map(key=>[key,$(key).value.trim()]));
 $('submitInfo').disabled=true;$('formMessage').textContent='Submitting…';
 try{
  const {error}=await sb.rpc(registration?'submit_guest_registration':'submit_guest_information',{p_token:token,p_info:info});if(error)throw error;
  $('informationForm').hidden=true;$('success').hidden=false;
 }catch(error){$('formMessage').textContent=error.message||'Unable to submit. Please try again.';$('submitInfo').disabled=false}
};
boot().catch(()=>{$('message').textContent='Unable to check this link. Please reopen your original link and try again.'});

