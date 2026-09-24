-- Only public roster fields leave this function. Player contact and travel data remain private.
create or replace function public.tournament_public_roster(p_tournament_id uuid)
returns table(player_id uuid, player_name text, jersey_number integer, roster_status text)
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.tournaments t where t.id = p_tournament_id
  ) then
    raise exception 'Tournament unavailable';
  end if;
  return query
    select tp.player_id, p.name::text, coalesce(tp.jersey_number,p.jersey_number), tp.roster_status::text
    from public.tournament_players tp
    join public.players p on p.id = tp.player_id
    where tp.tournament_id = p_tournament_id
      and tp.roster_status in ('Interested','Selected','Confirmed')
      and p.deleted_at is null
    order by case tp.roster_status when 'Confirmed' then 0 when 'Selected' then 1 else 2 end, p.name;
end;
$$;
revoke all on function public.tournament_public_roster(uuid) from public, anon;
grant execute on function public.tournament_public_roster(uuid) to authenticated;
