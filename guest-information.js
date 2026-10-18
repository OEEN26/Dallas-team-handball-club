'use strict';
const sb=supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
const $=id=>document.getElementById(id), fields=['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone','instagram','facebook','tiktok','profile_photo'];
const params=new URLSearchParams(location.hash.slice(1)),token=params.get('token'),registration=params.get('registration')==='1';
history.replaceState(null,'',location.pathname);
const photoEditor=GuestMedia.editor();
$('fullNameField').hidden=registration;$('name').required=!registration;
$('firstNameField').hidden=!registration;$('lastNameField').hidden=!registration;
$('first_name').required=registration;$('last_name').required=registration;
async function boot(){
 const {data,error}=await sb.rpc(registration?'guest_registration_information':'guest_information',{p_token:token});
 if(error){$('message').textContent='This link is invalid, expired, revoked, or already used. Ask Dallas THC for a new information link.';return}
 fields.forEach(key=>{$(key).value=data.info?.[key]||''});$('title').textContent=registration?'Guest player registration':'Guest information for '+data.name;
 photoEditor.reset();$('message').textContent='';$('informationForm').hidden=false;
}
const ageLabel=document.createElement('label');ageLabel.textContent='Participant’s date of birth';ageLabel.htmlFor='guestDob';const ageInput=document.createElement('input');ageInput.id='guestDob';ageInput.type='date';ageInput.required=true;ageInput.max=new Date().toISOString().slice(0,10);const ageHelp=document.createElement('p');ageHelp.textContent='Participants under 18 register through a parent or legal guardian.';const youthLink=document.createElement('a');youthLink.href='./youth-registration.html';youthLink.textContent='Open Youth & family registration';const adultFields=document.createElement('div');adultFields.hidden=true;adultFields.append(...Array.from($('informationForm').children));$('informationForm').append(ageLabel,ageInput,ageHelp,youthLink,adultFields);ageInput.onchange=()=>{const cut=new Date();cut.setFullYear(cut.getFullYear()-18);const adult=!!ageInput.value&&new Date(ageInput.value+'T12:00:00')<=cut;adultFields.hidden=!adult;youthLink.hidden=adult;ageHelp.textContent=adult?'Continue with adult guest registration.':'Participants under 18 must use Youth & family registration with a guardian.'};
$('informationForm').onsubmit=async event=>{
 event.preventDefault();const birth=ageInput.value,cut=new Date();cut.setFullYear(cut.getFullYear()-18);if(!birth||new Date(birth+'T12:00:00')>new Date()){$('formMessage').textContent='Enter a valid participant birth date.';return}if(new Date(birth+'T12:00:00')>cut){location.href='./youth-registration.html';return}if($('submitInfo').disabled)return;if(photoEditor.busy()){$('formMessage').textContent='Please wait for your photo to finish preparing.';return}
 if(registration){
  const first=$('first_name').value.trim(),last=$('last_name').value.trim();
  if(!first||!last){$('formMessage').textContent='Please enter both your first and last name.';(!first?$('first_name'):$('last_name')).focus();return}
  $('name').value=first+' '+last;
 }
 const info={...Object.fromEntries(fields.map(key=>[key,$(key).value.trim()])),date_of_birth:birth};
 $('submitInfo').disabled=true;$('formMessage').textContent='Submitting…';
 try{
  const {error}=await sb.rpc(registration?'submit_guest_registration':'submit_guest_information',{p_token:token,p_info:info});if(error)throw error;
  $('informationForm').hidden=true;$('success').hidden=false;
 }catch(error){$('formMessage').textContent=error.message||'Unable to submit. Please try again.';$('submitInfo').disabled=false}
};
boot().catch(()=>{$('message').textContent='Unable to check this link. Please reopen your original link and try again.'});


