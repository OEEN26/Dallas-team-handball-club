/* Membership submissions are private; only an admin or manager can approve them. */
window.ClubMembership=(()=>{
  const $=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const localDate=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const period=value=>new Intl.DateTimeFormat('en-US',{timeZone:'UTC',month:'long',year:'numeric'}).format(new Date(value+'T12:00:00Z'));
  const label=status=>({Pending:'Pending review',Approved:'Paid / Approved',Returned:'Needs correction'}[status]||status);
  function initPlayer({sb,player}){
    $('memberPeriod').value=localDate().slice(0,7);$('memberDate').value=localDate();$('memberDate').max=localDate();
    $('membershipSubmissionForm').onsubmit=async event=>{
      event.preventDefault();const button=$('memberSubmit'),message=$('memberSubmitMessage');button.disabled=true;message.textContent='Submitting…';
      try{
        const {error}=await sb.rpc('submit_membership_payment',{p_period:$('memberPeriod').value+'-01',p_amount:Number($('memberAmount').value),p_payment_date:$('memberDate').value,p_method:$('memberMethod').value,p_reference:$('memberReference').value.trim(),p_notes:$('memberNotes').value.trim()});
        if(error)throw error;
        message.textContent='Submitted. Your payment is pending admin review.';$('memberReference').value='';$('memberNotes').value='';
        await loadPlayer(sb,player);
      }catch(error){message.textContent=error.message||'Unable to submit. Please try again.'}finally{button.disabled=false}
    };
  }
  async function loadPlayer(sb,player){
    const [submissions,account]=await Promise.all([sb.from('membership_payment_submissions').select('*').eq('player_id',player.id).order('created_at',{ascending:false}),sb.from('players').select('membership_status').eq('id',player.id).single()]);
    if(account.data)player.membership_status=account.data.membership_status;
    const rows=submissions.data||[],pending=rows.some(x=>x.status==='Pending');
    $('membershipStatus').textContent=pending?'Pending review':player.membership_status||'Unpaid';
    $('membershipSubmissions').innerHTML=submissions.error?'<p>Unable to load submissions. Please refresh and try again.</p>':rows.map(x=>'<div class="item"><div class="row"><b>'+esc(period(x.period_start))+'</b><span class="chip">'+esc(label(x.status))+'</span></div><p>$'+Number(x.amount).toFixed(2)+' • '+esc(x.payment_date)+' • '+esc(x.method)+'</p><div class="muted">Reference: '+esc(x.transaction_reference)+'</div>'+(x.notes?'<p>'+esc(x.notes)+'</p>':'')+(x.admin_note?'<p>Admin note: '+esc(x.admin_note)+'</p>':'')+(x.status==='Returned'?'<button type="button" class="btn" data-correct-payment="'+esc(x.id)+'" style="margin-top:10px">Correct & resubmit</button>':'')+'</div>').join('')||'<div class="empty">No payment submissions yet.</div>';
    $('membershipSubmissions').onclick=event=>{
      const button=event.target.closest('[data-correct-payment]');if(!button)return;const row=rows.find(x=>x.id===button.dataset.correctPayment);if(!row)return;
      $('memberPeriod').value=row.period_start.slice(0,7);$('memberAmount').value=row.amount;$('memberDate').value=row.payment_date;$('memberMethod').value=row.method;$('memberReference').value=row.transaction_reference;$('memberNotes').value=row.notes||'';
      $('memberSubmitMessage').textContent='Correct the details above, then submit for review again.';$('membershipSubmissionForm').scrollIntoView({behavior:'smooth',block:'start'});
    };
  }
  async function loadAdmin(sb,onReviewed){
    const list=$('membershipReviewQueue');if(!list)return;
    const {data:rows,error}=await sb.from('membership_payment_submissions').select('*,players(name,team)').eq('status','Pending').order('created_at');
    list.innerHTML=error?'<p>Unable to load payment submissions. Please refresh and try again.</p>':(rows||[]).map(x=>'<div class="item"><div class="row"><b>'+esc(x.players?.name||'Player')+'</b><span class="chip">$'+Number(x.amount).toFixed(2)+'</span></div><p>'+esc(x.players?.team)+' • '+esc(period(x.period_start))+' • '+esc(x.payment_date)+'</p><p>'+esc(x.method)+' • Reference: '+esc(x.transaction_reference)+'</p>'+(x.notes?'<p>'+esc(x.notes)+'</p>':'')+'<div class="field"><label for="reviewNote_'+esc(x.id)+'">Admin note (required when returning)</label><textarea id="reviewNote_'+esc(x.id)+'" maxlength="1000"></textarea></div><div class="actions" style="margin-top:10px"><button class="btn primary" data-review-id="'+esc(x.id)+'" data-decision="Approved">Verify & approve payment</button><button class="btn" data-review-id="'+esc(x.id)+'" data-decision="Returned">Return for correction</button></div></div>').join('')||'<div class="empty">No payments are waiting for approval.</div>';
    list.onclick=async event=>{
      const button=event.target.closest('[data-review-id]');if(!button)return;const id=button.dataset.reviewId,decision=button.dataset.decision,note=$('reviewNote_'+id).value.trim(),message=$('membershipReviewMessage');
      if(decision==='Returned'&&!note){message.textContent='Add a note explaining what the player needs to correct.';return}
      if(decision==='Approved'&&!confirm('Have you verified this payment in the club payment records? Approving marks the membership paid.'))return;
      const buttons=Array.from(list.querySelectorAll('button'));buttons.forEach(x=>x.disabled=true);message.textContent='Saving review…';
      try{const {error}=await sb.rpc('review_membership_payment',{p_submission_id:id,p_decision:decision,p_note:note});if(error)throw error;message.textContent=decision==='Approved'?'Payment approved and membership marked paid.':'Returned to the player for correction.';await onReviewed()}
      catch(error){message.textContent=error.message||'Review could not be saved.';buttons.forEach(x=>x.disabled=false)}
    };
  }
  return {initPlayer,loadPlayer,loadAdmin};
})();
