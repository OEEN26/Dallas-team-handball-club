-- Transaction-only fixtures: creates no accounts, children, signatures, or awards permanently.
begin;
create temp table youth_test_state(k text primary key,v text);
grant all on youth_test_state to authenticated;
do $$ declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); begin
 insert into auth.users(id,email,email_confirmed_at,aud,role) values(a,'youth-fixture-parent@example.invalid',now(),'authenticated','authenticated'),(b,'youth-fixture-other@example.invalid',now(),'authenticated','authenticated'),(c,'youth-fixture-unconfirmed@example.invalid',null,'authenticated','authenticated');
 insert into public.profiles(id,full_name,role) values(a,'Fixture Parent','player'),(b,'Fixture Other','player'),(c,'Fixture Unconfirmed','player') on conflict(id) do nothing;
 insert into youth_test_state values('parent',a::text),('other',b::text),('unconfirmed',c::text),('admin',(select id::text from public.profiles where role='admin' limit 1)),('season',(select id::text from public.seasons where is_current limit 1));
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='parent'),true);
set local role authenticated;
do $$ declare pid uuid; second uuid; begin
 pid:=public.register_youth_player('Fixture','Child',(current_date-interval '12 years')::date,'Fixture Parent','Parent','5551234567',true);
 second:=public.register_youth_player('Fixture','Sibling',(current_date-interval '8 years')::date,'Fixture Parent','Parent','5551234567',true);
 insert into youth_test_state values('child',pid::text),('sibling',second::text);
 if (select count(*) from public.youth_registrations where player_id in(pid,second))<>2 then raise exception 'FAIL guardian cannot see both children'; end if;
 if (select team from public.players where id=pid)<>'Youth' or (select status from public.players where id=pid)<>'Inactive' then raise exception 'FAIL youth not separate/inactive'; end if;
 begin perform public.register_youth_player('Adult','Fixture',(current_date-interval '18 years')::date,'Fixture Parent','Parent','5551234567',true);raise exception 'FAIL adult accepted'; exception when raise_exception then if SQLERRM='FAIL adult accepted' then raise; end if; end;
 begin perform public.register_youth_player('No','Consent',(current_date-interval '10 years')::date,'Fixture Parent','Parent','5551234567',false);raise exception 'FAIL guardian attestation bypass'; exception when raise_exception then if SQLERRM='FAIL guardian attestation bypass' then raise; end if; end;
 begin perform public.invite_youth_guardian(pid,'other@example.invalid');raise exception 'FAIL player invited guardian'; exception when raise_exception then if SQLERRM='FAIL player invited guardian' then raise; end if; end;
 begin perform public.approve_season_packet(gen_random_uuid());raise exception 'FAIL player approved packet'; exception when raise_exception then if SQLERRM='FAIL player approved packet' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='other'),true);
do $$ declare pid uuid:=(select v::uuid from youth_test_state where k='child');begin
 if exists(select 1 from public.youth_registrations where player_id=pid) or exists(select 1 from public.players where id=pid) or exists(select 1 from public.player_directory_public where id=pid) or exists(select 1 from public.player_bio_public where id=pid) then raise exception 'FAIL unrelated user can read youth record'; end if;
 begin perform public.sign_season_player_agreement((select v::uuid from youth_test_state where k='season'),pid,'DTHC-PLAYER-COMMITMENT-v1',(current_date-interval '12 years')::date,'Fixture Parent','parent_or_guardian','youth-fixture-parent@example.invalid','5551234567',true);raise exception 'FAIL unrelated user signed'; exception when raise_exception then if SQLERRM='FAIL unrelated user signed' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='unconfirmed'),true);
do $$ begin
 begin perform public.register_youth_player('No','Email',(current_date-interval '10 years')::date,'Unverified Parent','Parent','5551234567',true);raise exception 'FAIL unverified email registered youth'; exception when raise_exception then if SQLERRM='FAIL unverified email registered youth' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='parent'),true);
do $$ declare pid uuid:=(select v::uuid from youth_test_state where k='child'); sid uuid:=(select v::uuid from youth_test_state where k='season'); pk uuid; begin
 begin perform public.submit_season_packet(sid,pid,'DTHC-2026-27-v1','Fixture Child',(current_date-interval '25 years')::date,'Fixture Parent','self',null,null,'Fixture Parent','5551234567',null,true,true,true,true,true,false);raise exception 'FAIL birthday spoof accepted'; exception when raise_exception then if SQLERRM='FAIL birthday spoof accepted' then raise; end if; end;
 pk:=public.submit_season_packet(sid,pid,'DTHC-2026-27-v1','Fixture Child',(current_date-interval '12 years')::date,'Fixture Parent','parent_or_guardian','youth-fixture-parent@example.invalid','5551234567','Fixture Parent','5551234567','Fixture allergy note',true,true,true,true,true,false);
 insert into youth_test_state values('packet',pk::text);
 if (select media_consent from public.season_packets where id=pk) is distinct from false then raise exception 'FAIL declined media not saved'; end if;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='admin'),true);
do $$ begin
 begin perform public.approve_season_packet((select v::uuid from youth_test_state where k='packet'));raise exception 'FAIL approved without player agreement'; exception when raise_exception then if SQLERRM='FAIL approved without player agreement' then raise; end if; end;
 begin update public.players set status='Active' where id=(select v::uuid from youth_test_state where k='child');raise exception 'FAIL direct activation bypass'; exception when raise_exception then if SQLERRM='FAIL direct activation bypass' then raise; end if; end;
 begin update public.players set team='Men' where id=(select v::uuid from youth_test_state where k='child');raise exception 'FAIL adult team bypass'; exception when raise_exception then if SQLERRM='FAIL adult team bypass' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='parent'),true);
select public.sign_season_player_agreement((select v::uuid from youth_test_state where k='season'),(select v::uuid from youth_test_state where k='child'),'DTHC-PLAYER-COMMITMENT-v1',(current_date-interval '12 years')::date,'Fixture Parent','parent_or_guardian','youth-fixture-parent@example.invalid','5551234567',true);
select set_config('request.jwt.claim.sub',(select v from youth_test_state where k='admin'),true);
select public.approve_season_packet((select v::uuid from youth_test_state where k='packet'));
do $$ declare pid uuid:=(select v::uuid from youth_test_state where k='child'); begin
 if (select status from public.players where id=pid)<>'Active' or not exists(select 1 from public.season_registrations where player_id=pid and status='Active') then raise exception 'FAIL complete guardian packet did not activate'; end if;

end $$;
reset role;
do $$ begin if not exists(select 1 from public.player_season_awards where player_id=(select v::uuid from youth_test_state where k='child')) then raise exception 'FAIL season medal missing'; end if;end $$;
rollback;
