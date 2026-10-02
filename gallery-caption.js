/* Caption edits belong to the signed-in player's own gallery. */
window.ClubGalleryCaptions=(()=>{
 let config=null,dialog=null,currentId=null,opener=null,saving=false;
 function ensureDialog(){if(dialog)return;
  dialog=document.createElement('dialog');dialog.className='gallery-caption-dialog';dialog.setAttribute('aria-labelledby','galleryCaptionTitle');
  dialog.innerHTML='<form><h2 id="galleryCaptionTitle">Edit photo caption</h2><img class="gallery-caption-preview" alt="Photo being edited"><label for="editGalleryCaption">Caption</label><textarea id="editGalleryCaption" rows="4" maxlength="1000" placeholder="Add a tournament, year, team, or memory…"></textarea><p class="gallery-caption-message" role="status" aria-live="polite"></p><div class="caption-actions"><button type="button" data-caption-cancel>Cancel</button><button type="submit">Save caption</button></div></form>';
  document.body.append(dialog);
  dialog.querySelector('[data-caption-cancel]').onclick=()=>{if(!saving)dialog.close()};
  dialog.addEventListener('cancel',event=>{if(saving)event.preventDefault()});
  dialog.addEventListener('close',()=>{const replacement=document.querySelector('[data-edit-caption="'+currentId+'"]');(replacement||opener)?.focus();currentId=null});
  dialog.querySelector('form').onsubmit=async event=>{
   event.preventDefault();if(saving||!currentId)return;const message=dialog.querySelector('.gallery-caption-message'),buttons=dialog.querySelectorAll('button'),input=dialog.querySelector('textarea');saving=true;buttons.forEach(b=>b.disabled=true);input.disabled=true;message.textContent='Saving caption…';
   try{
    const caption=input.value.trim()||null;const {error}=await config.sb.from('player_gallery').update({caption}).eq('id',currentId).eq('player_id',config.playerId).eq('user_id',config.userId).select('id,caption').single();
    if(error)throw error;
    await config.onSaved();dialog.close();const notice=document.getElementById('galleryMsg');if(notice)notice.textContent=caption?'Photo caption saved.':'Photo caption removed.';
   }catch(error){message.textContent=error.message||'Unable to save. Please try again.'}finally{saving=false;buttons.forEach(b=>b.disabled=false);input.disabled=false}
  };
 }
 document.addEventListener('click',event=>{const button=event.target.closest('[data-edit-caption]');if(!button||!config)return;const item=config.items.find(x=>x.id===button.dataset.editCaption);if(!item)return;ensureDialog();currentId=item.id;opener=button;dialog.querySelector('textarea').value=item.caption||'';dialog.querySelector('.gallery-caption-preview').src=item.image_url;dialog.querySelector('.gallery-caption-message').textContent='';dialog.showModal();dialog.querySelector('textarea').focus()});
 return {init(options){config=options}};
})();
