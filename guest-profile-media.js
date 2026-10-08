'use strict';
window.GuestMedia = (() => {
 const safePhoto = value => typeof value === 'string' && value.length <= 180000 && /^data:image\/jpeg;base64,[A-Za-z0-9+/]+=*$/.test(value) ? value : '';
 const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const labels = {name:'Full name',team:'Team',email:'Email',phone:'Phone',home_club:'Home club',position:'Position',shirt_size:'Shirt size',emergency_name:'Emergency contact',emergency_phone:'Emergency phone',instagram:'Instagram',facebook:'Facebook',tiktok:'TikTok'};
 function avatar(info, large=false) {
  const photo=safePhoto(info?.profile_photo), initials=(info?.name||'Guest').trim().split(/\s+/).slice(0,2).map(s=>s[0]).join('');
  return '<span class="guest-avatar'+(large?' large':'')+'">'+(photo?'<img src="'+photo+'" alt="" loading="lazy">':escape(initials))+'</span>';
 }
 function detail(key,value) {
  if(key==='profile_photo') return safePhoto(value)?avatar({profile_photo:value},true):'—';
  if(['instagram','facebook','tiktok'].includes(key) && value && /^@?[A-Za-z0-9._-]{1,100}$/.test(value)){
   const handle=value.replace(/^@/,''), base={instagram:'https://www.instagram.com/',facebook:'https://www.facebook.com/',tiktok:'https://www.tiktok.com/@'}[key];
   return '<a href="'+base+encodeURIComponent(handle)+'" target="_blank" rel="noopener noreferrer">@'+escape(handle)+'</a>';
  }
  return escape(value||'—');
 }
 function editor() {
  const input=document.getElementById('profile_photo'), preview=document.getElementById('photoPreview'), file=document.getElementById('photoFile'), status=document.getElementById('photoStatus');
  let working=false, generation=0;
  const refresh=()=>{preview.innerHTML=avatar({profile_photo:input.value,name:document.getElementById('name').value},true)};
  file.onchange=async()=>{
   const selected=file.files[0];if(!selected)return;
   const current=++generation;working=true;status.textContent='Preparing photo…';
   try{
    if(selected.size>15000000)throw Error('Choose a photo smaller than 15 MB.');
    const url=URL.createObjectURL(selected), image=new Image();
    try{image.src=url;await image.decode();}finally{URL.revokeObjectURL(url)}
    const canvas=document.createElement('canvas');canvas.width=canvas.height=320;
    const ctx=canvas.getContext('2d');ctx.fillStyle='#151d17';ctx.fillRect(0,0,320,320);
    const scale=Math.min(320/image.width,320/image.height),w=image.width*scale,h=image.height*scale;
    ctx.drawImage(image,(320-w)/2,(320-h)/2,w,h);
    let result=canvas.toDataURL('image/jpeg',.82);
    if(result.length>180000)result=canvas.toDataURL('image/jpeg',.55);
    if(!safePhoto(result))throw Error('Unable to prepare this photo. Try a smaller JPG or PNG.');
    if(current===generation){input.value=result;refresh();status.textContent='Photo ready. Submit or save to keep it.'}
   }catch(error){if(current===generation)status.textContent=error.message||'Choose a JPG, PNG, or WebP photo.'}
   finally{if(current===generation)working=false;file.value=''}
  };
  document.getElementById('removePhoto').onclick=()=>{generation++;working=false;input.value='';refresh();status.textContent='Photo removed. Save to keep this change.'};
  return {refresh,busy:()=>working,reset:()=>{generation++;working=false;file.value='';status.textContent='';refresh()}};
 }
 return {avatar,detail,labels,editor};
})();
