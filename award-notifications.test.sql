begin;
create temp table notice_test(k text primary key,v text);
grant all on notice_test to authenticated;
do $$declare u uuid:=gen_random_uuid();o uuid:=gen_random_uuid();g uuid:=gen_random_uuid();late uuid:=gen_random_uuid();begin
 insert into auth.users(id,email,email_confirmed_at,aud,role) values(u,'award-notice-fixture-player@example.invalid',now(),'authenticated','authenticated'),(o,'award-notice-fixture-other@example.invalid',now(),'authenticated','authenticated'),(g,'award-notice-fixture-guardian@example.invalid',now(),'authenticated','authenticated'),(late,'award-notice-fixture-late@example.invalid',now(),'authenticated','authenticated');
 insert into public.profiles(id,full_name,role) values(u,'Award Fixture Player','player'),(o,'Award Fixture Other','player'),(g,'Award Fixture Guardian','player'),(late,'Award Fixture Late','player') on conflict(id) do nothing;
 insert into notice_test values('user',u::text),('other',o::text),('guardian',g::text),('late_user',late::text),('admin',(select id::text from public.profiles where role='admin' limit 1));
end $$;
select set_config('request.jwt.claim.sub',(select v from notice_test where k='guardian'),true);
set local role authenticated;
insert into notice_test values('child',public.register_youth_player('Award','Fixture Child',(current_date-interval '10 years')::date,'Award Fixture Guardian','Parent','5551234567',true)::text);
select set_config('request.jwt.claim.sub',(select v from notice_test where k='admin'),true);
do $$declare a uuid;p uuid;late uuid;g uuid;begin
 insert into public.award_definitions(title,description) values('Notification Fixture Medal','Award notification test, rolled back') returning id into a;
 insert into public.players(name,team,status,user_id) values('Award Fixture Player','Men','Inactive',(select v::uuid from notice_test where k='user')) returning id into p;
 insert into public.players(name,team,status) values('Award Fixture Late','Men','Inactive') returning id into late;
 insert into public.award_grants(award_id,player_id) values(a,p) returning id into g;
 insert into public.award_grants(award_id,player_id) values(a,(select v::uuid from notice_test where k='child'));
 insert into public.award_grants(award_id,player_id) values(a,late);
 insert into notice_test values('award',a::text),('grant',g::text),('player',p::text),('late_player',late::text);
end $$;
select set_config('request.jwt.claim.sub',(select v from notice_test where k='user'),true);
do $$declare n public.club_notifications%rowtype;begin
 select * into n from public.club_notifications where award_grant_id=(select v::uuid from notice_test where k='grant');
 if n.id is null or n.recipient_user_id<>auth.uid() or n.link<>'./player.html#seasonMedal' then raise exception 'FAIL player notice missing/wrong recipient/link';end if;
 if (select count(*) from public.club_notifications where award_grant_id in(select id from public.award_grants where award_id=(select v::uuid from notice_test where k='award')))<>1 then raise exception 'FAIL player can read someone else award notice';end if;
 insert into public.notification_reads(notification_id,user_id) values(n.id,auth.uid());
 if not exists(select 1 from public.notification_reads where notification_id=n.id and user_id=auth.uid()) then raise exception 'FAIL mark-read failed';end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from notice_test where k='other'),true);
do $$begin
 if exists(select 1 from public.club_notifications where award_grant_id in(select id from public.award_grants where award_id=(select v::uuid from notice_test where k='award'))) then raise exception 'FAIL private notice leaked';end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from notice_test where k='guardian'),true);
do $$begin
 if (select count(*) from public.club_notifications where award_grant_id in(select id from public.award_grants where award_id=(select v::uuid from notice_test where k='award')))<>1 then raise exception 'FAIL guardian did not receive child notice';end if;
 if not exists(select 1 from public.club_notifications where title='Award Fixture Child earned an award!' and recipient_user_id=auth.uid() and link like './youth-registration.html#player-%') then raise exception 'FAIL guardian content/link incorrect';end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from notice_test where k='admin'),true);
update public.award_grants set revoked_at=now() where id=(select v::uuid from notice_test where k='grant');
update public.award_grants set revoked_at=null where id=(select v::uuid from notice_test where k='grant');
update public.players set user_id=(select v::uuid from notice_test where k='late_user') where id=(select v::uuid from notice_test where k='late_player');
reset role;
do $$declare a uuid:=(select v::uuid from notice_test where k='award');begin
 if (select count(*) from public.club_notifications where award_grant_id=(select v::uuid from notice_test where k='grant'))<>2 then raise exception 'FAIL reaward did not send exactly one additional notice';end if;
 if (select count(*) from public.club_notifications where award_grant_id in(select id from public.award_grants where award_id=a))<>4 then raise exception 'FAIL unexpected total notices after late link/reaward';end if;
 if not exists(select 1 from public.club_notifications where recipient_user_id=(select v::uuid from notice_test where k='late_user') and award_grant_id in(select id from public.award_grants where award_id=a)) then raise exception 'FAIL late-linked account not notified';end if;
end $$;
rollback;
