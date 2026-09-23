-- Admin-only custom awards, retained history, and public badge artwork.
-- Season participation remains automatic in player_season_awards.
create or replace function club_internal.is_awards_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;
revoke all on function club_internal.is_awards_admin() from public, anon;
grant usage on schema club_internal to authenticated;
grant execute on function club_internal.is_awards_admin() to authenticated;

create table public.award_definitions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 2 and 80),
  description text not null check (length(btrim(description)) between 3 and 500),
  image_path text check (image_path is null or (length(image_path) <= 240 and image_path ~ '^awards/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp)$')),
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.award_definitions enable row level security;
revoke all on public.award_definitions from public, anon, authenticated;
grant select, insert on public.award_definitions to authenticated;
grant update(title,description,image_path,is_active) on public.award_definitions to authenticated;
create policy award_definitions_read on public.award_definitions
  for select to authenticated using (is_active or (select club_internal.is_awards_admin()));
create policy award_definitions_admin_insert on public.award_definitions
  for insert to authenticated with check ((select club_internal.is_awards_admin()));
create policy award_definitions_admin_update on public.award_definitions
  for update to authenticated using ((select club_internal.is_awards_admin()))
  with check ((select club_internal.is_awards_admin()));

create table public.award_grants (
  id uuid primary key default gen_random_uuid(),
  award_id uuid not null references public.award_definitions(id),
  player_id uuid not null references public.players(id) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by uuid not null references public.profiles(id),
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id),
  unique(award_id,player_id)
);
create index award_grants_player_idx on public.award_grants(player_id) where revoked_at is null;
alter table public.award_grants enable row level security;
revoke all on public.award_grants from public, anon, authenticated;
grant select, insert on public.award_grants to authenticated;
grant update(revoked_at) on public.award_grants to authenticated;
create policy award_grants_read on public.award_grants
  for select to authenticated using (revoked_at is null or (select club_internal.is_awards_admin()));
create policy award_grants_admin_insert on public.award_grants
  for insert to authenticated with check ((select club_internal.is_awards_admin()));
create policy award_grants_admin_update on public.award_grants
  for update to authenticated using ((select club_internal.is_awards_admin()))
  with check ((select club_internal.is_awards_admin()));

create table public.award_history (
  id bigint generated always as identity primary key,
  award_id uuid not null references public.award_definitions(id),
  player_id uuid references public.players(id) on delete set null,
  action text not null check (action in ('created','edited','archived','restored','granted','revoked')),
  actor_id uuid not null references public.profiles(id),
  happened_at timestamptz not null default now()
);
create index award_history_recent_idx on public.award_history(happened_at desc);
alter table public.award_history enable row level security;
revoke all on public.award_history from public, anon, authenticated;
grant select on public.award_history to authenticated;
create policy award_history_admin_read on public.award_history
  for select to authenticated using ((select club_internal.is_awards_admin()));

create or replace function club_internal.stamp_award_definition()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not (select club_internal.is_awards_admin()) then raise exception 'Admin access required'; end if;
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$$;
revoke all on function club_internal.stamp_award_definition() from public, anon, authenticated;
create trigger stamp_award_definition before insert or update on public.award_definitions
  for each row execute function club_internal.stamp_award_definition();

create or replace function club_internal.stamp_award_grant()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not (select club_internal.is_awards_admin()) then raise exception 'Admin access required'; end if;
  if tg_op = 'INSERT' then
    if not exists (select 1 from public.award_definitions d where d.id = new.award_id and d.is_active) then
      raise exception 'Choose an active award';
    end if;
    if not exists (select 1 from public.players p where p.id = new.player_id and p.deleted_at is null) then
      raise exception 'Choose an active player profile';
    end if;
    new.granted_by := auth.uid(); new.granted_at := now(); new.revoked_at := null; new.revoked_by := null;
  else
    new.award_id := old.award_id; new.player_id := old.player_id;
    if old.revoked_at is null and new.revoked_at is not null then
      new.revoked_at := now(); new.revoked_by := auth.uid();
      new.granted_at := old.granted_at; new.granted_by := old.granted_by;
    elsif old.revoked_at is not null and new.revoked_at is null then
      if not exists (select 1 from public.award_definitions d where d.id = new.award_id and d.is_active) then
        raise exception 'Cannot award an archived badge';
      end if;
      new.granted_at := now(); new.granted_by := auth.uid(); new.revoked_by := null;
    else
      raise exception 'Only award or revoke changes are permitted';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function club_internal.stamp_award_grant() from public, anon, authenticated;
create trigger stamp_award_grant before insert or update on public.award_grants
  for each row execute function club_internal.stamp_award_grant();

create or replace function club_internal.log_award_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare event_action text;
begin
  if tg_table_name = 'award_definitions' then
    if tg_op = 'INSERT' then event_action := 'created';
    elsif new.is_active is distinct from old.is_active then
      event_action := case when new.is_active then 'restored' else 'archived' end;
    else event_action := 'edited'; end if;
    insert into public.award_history(award_id,action,actor_id)
    values (new.id,event_action,auth.uid());
  else
    event_action := case when new.revoked_at is null then 'granted' else 'revoked' end;
    insert into public.award_history(award_id,player_id,action,actor_id)
    values (new.award_id,new.player_id,event_action,auth.uid());
  end if;
  return new;
end;
$$;
revoke all on function club_internal.log_award_change() from public, anon, authenticated;
create trigger log_award_definition after insert or update on public.award_definitions
  for each row execute function club_internal.log_award_change();
create trigger log_award_grant after insert or update on public.award_grants
  for each row execute function club_internal.log_award_change();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('award-media','award-media',true,2097152,array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;
create policy award_media_read on storage.objects for select to public
  using (bucket_id = 'award-media');
create policy award_media_admin_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'award-media' and (select club_internal.is_awards_admin()));
