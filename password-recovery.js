'use strict';
const $=id=>document.getElementById(id);
const query=new URLSearchParams(location.search),fragment=new URLSearchParams(location.hash.slice(1));
const linkError=query.get('error')||query.get('error_code')||fragment.get('error')||fragment.get('error_code');
const sb=supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co','sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ',{auth:{detectSessionInUrl:!query.get('code')&&!query.get('token_hash')}});
let busy=false,verifiedUserId=null;
function message(text,error=false){$('message').textContent=text;$('message').classList.toggle('error',error)}
function cleanURL(){history.replaceState(null,'',location.pathname)}
function invalidLink(text='This reset link is invalid or expired. Request a new link and open the most recent email.'){verifiedUserId=null;$('resetForm').hidden=true;$('requestAgain').hidden=false;message(text,true);cleanURL()}
if($('requestForm')){
 $('requestForm').onsubmit=async e=>{e.preventDefault();if(busy||!$('requestForm').reportValidity())return;busy=true;$('send').disabled=true;message('Sending reset link…');try{const {error}=await sb.auth.resetPasswordForEmail($('email').value.trim(),{redirectTo:new URL('./player.html',location.href).href});if(error)throw error;message('If an account exists for that email, a password reset link will arrive shortly. Check your inbox and spam folder, and open the most recent reset email.')}catch(e){message(e.status===429||e.code==='over_email_send_rate_limit'?'Too many requests. Wait a few minutes before requesting another reset link.':'The reset email could not be sent. Please try again shortly.',true)}finally{busy=false;$('send').disabled=false}};
}
async function verifyRecovery(){
 if(linkError){invalidLink();return}
 try{
  if(query.get('token_hash')&&query.get('type')==='recovery'){const {error}=await sb.auth.verifyOtp({token_hash:query.get('token_hash'),type:'recovery'});if(error)throw error}
  else if(query.get('code')){const {error}=await sb.auth.exchangeCodeForSession(query.get('code'));if(error)throw error}
  const {data,error}=await sb.auth.getSession();if(error||!data.session)throw error||Error('No recovery session');
  const user=await sb.auth.getUser();if(user.error||!user.data.user)throw user.error||Error('Account could not be verified');
  verifiedUserId=user.data.user.id;cleanURL();$('resetForm').hidden=false;$('requestAgain').hidden=true;message('Set a new password for '+(user.data.user.email||'your account')+'.');
 }catch(e){invalidLink()}
}
if($('resetForm')){
 // The callback stays synchronous so it never blocks Supabase's auth lock.
 sb.auth.onAuthStateChange(event=>{if(event==='SIGNED_OUT'){verifiedUserId=null;$('resetForm').hidden=true;if($('success').hidden)invalidLink('Your reset session ended. Request a new reset link.')}});
 $('resetForm').onsubmit=async e=>{e.preventDefault();if(busy||!$('resetForm').reportValidity())return;const password=$('newPassword').value;if(password.length<8){message('Use at least 8 characters.',true);return}if(password!==$('confirmPassword').value){message('The passwords do not match.',true);return}if(!verifiedUserId){invalidLink();return}busy=true;$('save').disabled=true;message('Updating password…');try{const user=await sb.auth.getUser();if(user.error||user.data.user?.id!==verifiedUserId){invalidLink('Your reset session changed. Request a new reset link.');return}const {error}=await sb.auth.updateUser({password});if(error)throw error;$('newPassword').value='';$('confirmPassword').value='';$('resetForm').hidden=true;$('success').hidden=false;verifiedUserId=null;message('Password updated successfully.');await sb.auth.signOut({scope:'local'});cleanURL()}catch(e){if(e.code==='same_password')message('Choose a different password from your current password.',true);else if(e.code==='weak_password')message('Choose a stronger password. '+(e.message||''),true);else message('Your password could not be updated. '+(e.message||'Request a new reset link and try again.'),true)}finally{busy=false;$('save').disabled=false}};
 verifyRecovery();
}
