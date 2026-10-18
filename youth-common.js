/* Calendar dates use the club's local day, independent of the phone's timezone. */
(function(root){
 function today(){return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date())}
 function age(dob,on=today()){if(!/^\d{4}-\d{2}-\d{2}$/.test(dob||'')||dob>on)return null;const [y,m,d]=dob.split('-').map(Number),[ty,tm,td]=on.split('-').map(Number);const parsed=new Date(Date.UTC(y,m-1,d));if(parsed.getUTCFullYear()!==y||parsed.getUTCMonth()!==m-1||parsed.getUTCDate()!==d)return null;return ty-y-(tm<m||(tm===m&&td<d)?1:0)}
 const api={today,age,isMinor:dob=>age(dob)!==null&&age(dob)<18};root.ClubYouth=api;if(typeof module!=='undefined')module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:this);
