-- Keep season participation awards even after a different season becomes current.
-- The row is awarded once when an admin approves a season registration.
create table if not exists public.player_season_awards (
  player_id uuid not null references public.players(id) on delete cascade,
  season_id uuid not null references public.seasons(id),
  awarded_at timestamptz not null default now(),
  primary key (player_id, season_id)
);
alter table public.player_season_awards enable row level security;
revoke all on public.player_season_awards from public, anon, authenticated;

create or replace function public.record_season_award()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'Active' then
    insert into public.player_season_awards(player_id, season_id, awarded_at)
    values (new.player_id, new.season_id, coalesce(new.activated_at, now()))
    on conflict (player_id, season_id) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.record_season_award() from public, anon, authenticated;
create trigger record_season_award
  after insert or update of status on public.season_registrations
  for each row execute function public.record_season_award();

-- Award existing approved players without requiring them to register again.
insert into public.player_season_awards(player_id, season_id, awarded_at)
select r.player_id, r.season_id, coalesce(r.activated_at, r.updated_at, now())
from public.season_registrations r
where r.status = 'Active'
on conflict (player_id, season_id) do nothing;

-- A read-only projection of public medal metadata. Waivers and private details
-- are never included; unapproved registrations never create awards.
create or replace function public.player_season_medals()
returns table(player_id uuid, season_id uuid, season_name text, starts_on date, ends_on date, awarded_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select a.player_id, a.season_id, s.name, s.starts_on, s.ends_on, a.awarded_at
  from public.player_season_awards a
  join public.seasons s on s.id = a.season_id
  join public.players p on p.id = a.player_id
  where (select auth.uid()) is not null
    and p.deleted_at is null
  order by s.starts_on desc, a.awarded_at desc;
$$;
revoke all on function public.player_season_medals() from public, anon;
grant execute on function public.player_season_medals() to authenticated;
