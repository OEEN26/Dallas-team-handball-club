-- A small, authenticated-only projection for the current season medal.
-- Only approved status and season name are shared; signed packets remain private.
create or replace function public.current_season_medals()
returns table(player_id uuid, season_name text)
language sql stable security definer set search_path = '' as $$
  select r.player_id, s.name
  from public.season_registrations r
  join public.seasons s on s.id = r.season_id
  join public.players p on p.id = r.player_id
  where (select auth.uid()) is not null
    and s.is_current = true
    and r.status = 'Active'
    and p.deleted_at is null;
$$;
revoke all on function public.current_season_medals() from public, anon;
grant execute on function public.current_season_medals() to authenticated;
