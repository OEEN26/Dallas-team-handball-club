/* Render the selected square crop into the uploaded avatar, so every view matches. */
window.ClubPhotoCrop={create({stage,image,slider,reset,controls,onReady,onError}){
 let source=null,url=null,scale=1,x=0,y=0,base=1,side=0,sequence=0,disabled=false,gesture=null;const pointers=new Map();
 function clamp(){if(!source)return;const maxX=Math.max(0,(source.naturalWidth*base*scale-side)/2),maxY=Math.max(0,(source.naturalHeight*base*scale-side)/2);x=Math.max(-maxX,Math.min(maxX,x));y=Math.max(-maxY,Math.min(maxY,y))}
 function paint(){if(!source)return;clamp();image.style.width=source.naturalWidth*base*scale+'px';image.style.height=source.naturalHeight*base*scale+'px';image.style.transform='translate(-50%,-50%) translate('+x+'px,'+y+'px)';slider.value=String(scale);slider.setAttribute('aria-valuetext',Math.round(scale*100)+'% zoom')}
 function fit(){if(!source)return;const old=side;side=stage.clientWidth;base=Math.max(side/source.naturalWidth,side/source.naturalHeight);if(old){x*=side/old;y*=side/old}paint()}
 function zoom(value){if(disabled||!source)return;const old=scale;scale=Math.max(1,Math.min(4,value));x*=scale/old;y*=scale/old;paint()}
 function clear(){sequence++;if(url)URL.revokeObjectURL(url);url=null;source=null;controls.hidden=true;image.removeAttribute('src');pointers.clear();gesture=null;scale=1;x=y=0;side=0}
 async function setFile(file){clear();const ticket=sequence;const nextUrl=URL.createObjectURL(file);url=nextUrl;const next=new Image();
  try{await new Promise((resolve,reject)=>{next.onload=resolve;next.onerror=()=>reject(new Error('This photo cannot be opened for cropping. Please choose a JPEG, PNG or WebP image.'));next.src=nextUrl});if(ticket!==sequence)return;source=next;image.src=nextUrl;controls.hidden=false;fit();onReady?.()}
  catch(error){if(ticket!==sequence)return;clear();onError?.(error)}
 }
 function getCrop(){if(!source||!side)throw new Error('Choose a photo and wait for its preview.');const k=base*scale,size=side/k;return {sx:source.naturalWidth/2-size/2-x/k,sy:source.naturalHeight/2-size/2-y/k,size}}
 async function exportFile(){const {sx,sy,size}=getCrop();const canvas=document.createElement('canvas');canvas.width=canvas.height=768;const context=canvas.getContext('2d');if(!context)throw new Error('Your browser could not prepare this photo.');context.fillStyle='#fff';context.fillRect(0,0,768,768);context.drawImage(source,sx,sy,size,size,0,0,768,768);const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',0.92));if(!blob)throw new Error('Your browser could not save this crop. Please try another photo.');return new File([blob],'profile-crop.jpg',{type:'image/jpeg'})}
 slider.addEventListener('input',()=>zoom(Number(slider.value)));reset.addEventListener('click',()=>{if(disabled)return;scale=1;x=y=0;paint()});
 function measure(){const points=Array.from(pointers.values());if(points.length>=2){const [a,b]=points;return {cx:(a.x+b.x)/2,cy:(a.y+b.y)/2,distance:Math.hypot(a.x-b.x,a.y-b.y)}}return {cx:points[0]?.x||0,cy:points[0]?.y||0,distance:0}}
 function start(){gesture={...measure(),x,y,scale}}
 stage.addEventListener('pointerdown',event=>{if(disabled||!source||(event.pointerType==='mouse'&&event.button!==0))return;stage.setPointerCapture(event.pointerId);pointers.set(event.pointerId,{x:event.clientX,y:event.clientY});start()});
 stage.addEventListener('pointermove',event=>{if(disabled||!pointers.has(event.pointerId)||!gesture)return;pointers.set(event.pointerId,{x:event.clientX,y:event.clientY});const m=measure();if(pointers.size>=2&&gesture.distance>0)scale=Math.max(1,Math.min(4,gesture.scale*m.distance/gesture.distance));const ratio=scale/gesture.scale;x=gesture.x*ratio+m.cx-gesture.cx;y=gesture.y*ratio+m.cy-gesture.cy;paint()});
 function release(event){pointers.delete(event.pointerId);if(pointers.size)start();else gesture=null}stage.addEventListener('pointerup',release);stage.addEventListener('pointercancel',release);
 stage.addEventListener('keydown',event=>{if(disabled||!source)return;const step=event.shiftKey?24:8;if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key)){event.preventDefault();if(event.key==='ArrowLeft')x-=step;if(event.key==='ArrowRight')x+=step;if(event.key==='ArrowUp')y-=step;if(event.key==='ArrowDown')y+=step;paint()}});
 const observer=new ResizeObserver(()=>{if(source)fit()});observer.observe(stage);
 return {setFile,clear,getCrop,exportFile,setDisabled(value){disabled=value;slider.disabled=reset.disabled=value;if(value){pointers.clear();gesture=null}}};
}};
