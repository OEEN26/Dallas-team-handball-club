-- Targeted award notices share the club inbox but never the club-wide audience.
alter table public.club_notifications add column recipient_user_id uuid references auth.users(id) on delete cascade;
alter table public.club_notifications add column award_grant_id uuid references public.award_grants(id) on delete set null;
create index award_notice_recipient_idx on public.club_notifications(recipient_user_id,created_at desc) where recipient_user_id is not null;
create index award_notice_grant_idx on public.club_notifications(award_grant_id,recipient_user_id) where award_grant_id is not null;
create policy notification_recipient_isolation on public.club_notifications as restrictive for select to authenticated
 using(recipient_user_id is null or recipient_user_id=(select auth.uid()));
create or replace function club_internal.notify_award(p_grant_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare g public.award_grants%rowtype; recipient uuid; participant text; award_title text; youth boolean;
begin
 select * into g from public.award_grants where id=p_grant_id and revoked_at is null;
 if not found then return;end if;
 select p.name,y.player_id is not null,case when y.player_id is not null then y.guardian_user_id else p.user_id end
 into participant,youth,recipient from public.players p left join public.youth_registrations y on y.player_id=p.id where p.id=g.player_id and p.deleted_at is null;
 if recipient is null then return;end if;
 select title into award_title from public.award_definitions where id=g.award_id and is_active;
 if award_title is null then return;end if;
 insert into public.club_notifications(title,body,audience,link,created_by,recipient_user_id,award_grant_id)
 values(case when youth then participant||' earned an award!' else 'You earned an award!' end,participant||' received “'||award_title||'”. Open the profile to see the award.','All',case when youth then './youth-registration.html#player-'||g.player_id::text else './player.html#seasonMedal' end,g.granted_by,recipient,g.id);
end $$;
create or replace function club_internal.notify_new_award() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.revoked_at is null and (tg_op='INSERT' or old.revoked_at is not null) then perform club_internal.notify_award(new.id);end if;
 return new;
end $$;
create trigger notify_new_award after insert or update of revoked_at on public.award_grants for each row execute function club_internal.notify_new_award();
-- Profiles may be linked after a historical award. Deliver to the linked account once.
create or replace function club_internal.notify_linked_awards() returns trigger language plpgsql security definer set search_path='' as $$
declare pid uuid; recipient uuid; g record;
begin
 if tg_table_name='players' then
  if new.user_id is null or (tg_op='UPDATE' and old.user_id is not distinct from new.user_id) then return new;end if;
  pid:=new.id;recipient:=new.user_id;
 else
  if new.guardian_user_id is null or (tg_op='UPDATE' and old.guardian_user_id is not distinct from new.guardian_user_id) then return new;end if;
  pid:=new.player_id;recipient:=new.guardian_user_id;
 end if;
 for g in select a.id from public.award_grants a where a.player_id=pid and a.revoked_at is null and not exists(select 1 from public.club_notifications n where n.award_grant_id=a.id and n.recipient_user_id=recipient) loop
  perform club_internal.notify_award(g.id);
 end loop;
 return new;
end $$;
create trigger notify_player_linked_awards after update of user_id on public.players for each row execute function club_internal.notify_linked_awards();
create trigger notify_guardian_linked_awards after insert or update of guardian_user_id on public.youth_registrations for each row execute function club_internal.notify_linked_awards();
revoke all on function club_internal.notify_award(uuid),club_internal.notify_new_award(),club_internal.notify_linked_awards() from public,anon,authenticated;
