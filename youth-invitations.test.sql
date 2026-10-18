begin;
create temp table youth_invite_test(k text primary key,v text);
grant all on youth_invite_test to authenticated;
do $$ declare parent uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); owner uuid:=gen_random_uuid(); child uuid;begin
 insert into auth.users(id,email,email_confirmed_at,aud,role) values(parent,'fixture-invite-parent@example.invalid',now(),'authenticated','authenticated'),(other,'fixture-invite-other@example.invalid',now(),'authenticated','authenticated'),(owner,'fixture-invite-owner@example.invalid',now(),'authenticated','authenticated');
 insert into public.profiles(id,full_name,role) values(parent,'Invitation Parent','player'),(other,'Invitation Other','player'),(owner,'Legacy Child','player') on conflict(id) do nothing;
 insert into public.players(name,team,status,user_id) values('Invitation Child','Men','Inactive',owner) returning id into child;
 insert into public.player_profiles(player_id,user_id,date_of_birth) values(child,owner,(current_date-interval '14 years')::date);
 insert into youth_invite_test values('parent',parent::text),('other',other::text),('owner',owner::text),('child',child::text),('admin',(select id::text from public.profiles where role='admin' limit 1));
 if not exists(select 1 from public.youth_registrations where player_id=child) then raise exception 'FAIL legacy minor not classified'; end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_invite_test where k='admin'),true);
set local role authenticated;
insert into youth_invite_test values('old_token',public.invite_youth_guardian((select v::uuid from youth_invite_test where k='child'),'fixture-invite-parent@example.invalid'));
insert into youth_invite_test values('token',public.invite_youth_guardian((select v::uuid from youth_invite_test where k='child'),'fixture-invite-parent@example.invalid'));
select set_config('request.jwt.claim.sub',(select v from youth_invite_test where k='other'),true);
do $$begin
 begin perform public.claim_youth_guardian((select v from youth_invite_test where k='token'),'Invitation Other','Parent','5551234567',true);raise exception 'FAIL wrong email claimed';exception when raise_exception then if SQLERRM='FAIL wrong email claimed' then raise;end if;end;
 if exists(select 1 from public.player_bio_public where id=(select v::uuid from youth_invite_test where k='child')) then raise exception 'FAIL legacy minor bio leaked';end if;
 if exists(select 1 from public.profiles where id=(select v::uuid from youth_invite_test where k='owner')) then raise exception 'FAIL child account name leaked';end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_invite_test where k='parent'),true);
do $$begin
 begin perform public.claim_youth_guardian((select v from youth_invite_test where k='old_token'),'Invitation Parent','Parent','5551234567',true);raise exception 'FAIL old invite reused';exception when raise_exception then if SQLERRM='FAIL old invite reused' then raise;end if;end;
end $$;
select public.claim_youth_guardian((select v from youth_invite_test where k='token'),'Invitation Parent','Parent','5551234567',true);
do $$begin
 if not exists(select 1 from public.youth_registrations where player_id=(select v::uuid from youth_invite_test where k='child') and guardian_user_id=auth.uid()) then raise exception 'FAIL guardian not linked';end if;
 if not exists(select 1 from public.players where id=(select v::uuid from youth_invite_test where k='child') and user_id is null and team='Youth') then raise exception 'FAIL child account remained owner';end if;
 begin perform public.claim_youth_guardian((select v from youth_invite_test where k='token'),'Invitation Parent','Parent','5551234567',true);raise exception 'FAIL invite used twice';exception when raise_exception then if SQLERRM='FAIL invite used twice' then raise;end if;end;
end $$;
reset role;
rollback;
