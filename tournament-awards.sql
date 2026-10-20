-- Bulk awards use actual final participants, with the existing admin-only history triggers.
create or replace function club_internal.preview_tournament_award(p_award_id uuid,p_tournament_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare t public.tournaments%rowtype; revision text; recipients jsonb;
begin
 if not club_internal.is_awards_admin() then raise exception 'Admin access required'; end if;
 if not exists(select 1 from public.award_definitions where id=p_award_id and is_active) then raise exception 'Choose an active award.'; end if;
 select * into t from public.tournaments where id=p_tournament_id;
 if not found then raise exception 'Tournament not found.'; end if;
 if t.status<>'Completed' then raise exception 'Save the final participant roster and finish the tournament first.'; end if;
 select md5(t.updated_at::text||coalesce(string_agg(tp.id::text||':'||coalesce(tp.player_id::text,'unlinked')||':'||coalesce(p.deleted_at::text,'')||':'||coalesce(p.player_category,'')||':'||tp.player_name,'|' order by tp.id),'')),
 coalesce(jsonb_agg(jsonb_build_object('participant_id',tp.id,'player_id',tp.player_id,'name',tp.player_name,'team',tp.team,'status',case when tp.player_id is null then 'unlinked' when p.id is null or p.deleted_at is not null or p.player_category not in ('Member','Guest') then 'unavailable' when g.id is not null and g.revoked_at is null then 'already' when g.id is not null then 'revoked' else 'new' end) order by tp.player_name,tp.id),'[]'::jsonb)
 into revision,recipients from public.tournament_participants tp left join public.players p on p.id=tp.player_id left join public.award_grants g on g.player_id=tp.player_id and g.award_id=p_award_id where tp.tournament_id=t.id;
 return jsonb_build_object('tournament_id',t.id,'title',t.title,'revision',revision,'participants',recipients);
end $$;
create or replace function public.preview_tournament_award(p_award_id uuid,p_tournament_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select club_internal.preview_tournament_award(p_award_id,p_tournament_id); $$;

create or replace function club_internal.grant_tournament_award(p_award_id uuid,p_tournament_id uuid,p_expected_revision text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare preview jsonb; pid uuid; existing public.award_grants%rowtype; inserted uuid; granted integer:=0; restored integer:=0; skipped integer:=0; unlinked integer; unavailable integer;
begin
 if not club_internal.is_awards_admin() then raise exception 'Admin access required'; end if;
 -- Serializes award grants and prevents the previewed final roster from being replaced mid-batch.
 perform 1 from public.award_definitions where id=p_award_id and is_active for update;
 if not found then raise exception 'Choose an active award.'; end if;
 perform 1 from public.tournaments where id=p_tournament_id for share;
 if not found then raise exception 'Tournament not found.'; end if;
 perform p.id from public.players p join public.tournament_participants tp on tp.player_id=p.id where tp.tournament_id=p_tournament_id order by p.id for share of p;
 preview:=club_internal.preview_tournament_award(p_award_id,p_tournament_id);
 if p_expected_revision is null or p_expected_revision is distinct from preview->>'revision' then raise exception 'The participant roster changed. Refresh the preview before awarding.'; end if;
 select count(*) filter(where value->>'status'='unlinked'),count(*) filter(where value->>'status'='unavailable') into unlinked,unavailable from jsonb_array_elements(preview->'participants');
 for pid in select distinct (value->>'player_id')::uuid from jsonb_array_elements(preview->'participants') where value->>'status' in ('new','revoked','already') loop
  existing:=null;
  select * into existing from public.award_grants where award_id=p_award_id and player_id=pid for update;
  if existing.id is not null then
   if existing.revoked_at is null then skipped:=skipped+1;
   else update public.award_grants set revoked_at=null where id=existing.id; restored:=restored+1; end if;
  else
   inserted:=null;
   insert into public.award_grants(award_id,player_id) values(p_award_id,pid) on conflict(award_id,player_id) do nothing returning id into inserted;
   if inserted is not null then granted:=granted+1; else skipped:=skipped+1; end if;
  end if;
 end loop;
 return jsonb_build_object('granted',granted,'restored',restored,'already',skipped,'unlinked',unlinked,'unavailable',unavailable);
end $$;
create or replace function public.grant_tournament_award(p_award_id uuid,p_tournament_id uuid,p_expected_revision text)
returns jsonb language sql security invoker set search_path='' as $$ select club_internal.grant_tournament_award(p_award_id,p_tournament_id,p_expected_revision); $$;
revoke all on function club_internal.preview_tournament_award(uuid,uuid),club_internal.grant_tournament_award(uuid,uuid,text),public.preview_tournament_award(uuid,uuid),public.grant_tournament_award(uuid,uuid,text) from public,anon;
grant execute on function club_internal.preview_tournament_award(uuid,uuid),club_internal.grant_tournament_award(uuid,uuid,text),public.preview_tournament_award(uuid,uuid),public.grant_tournament_award(uuid,uuid,text) to authenticated;
