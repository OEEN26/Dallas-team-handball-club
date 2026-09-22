-- 2026–27 season packet. Apply to the existing Supabase project.
create table if not exists public.season_packets (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id),
  player_id uuid not null references public.players(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  document_version text not null,
  participant_name text not null,
  date_of_birth date not null,
  signer_name text not null,
  signer_capacity text not null check (signer_capacity in ('self','parent_or_guardian')),
  guardian_email text,
  guardian_phone text,
  emergency_name text not null,
  emergency_phone text not null,
  medical_notes text,
  risk_accepted boolean not null check (risk_accepted),
  release_accepted boolean not null check (release_accepted),
  emergency_accepted boolean not null check (emergency_accepted),
  concussion_accepted boolean not null check (concussion_accepted),
  conduct_accepted boolean not null check (conduct_accepted),
  media_consent boolean not null,
  signed_at timestamptz not null default now(),
  check (date_of_birth <= current_date),
  check ((signer_capacity = 'self' and guardian_email is null and guardian_phone is null)
    or (signer_capacity = 'parent_or_guardian' and guardian_email is not null and guardian_phone is not null))
);
create index if not exists season_packets_lookup on public.season_packets(season_id,player_id,signed_at desc);
alter table public.season_packets enable row level security;
grant select on public.season_packets to authenticated;
create policy "player or staff reads packet" on public.season_packets for select to authenticated using
  (user_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('admin','manager')));
-- No client insert/update/delete policy: submitted records are append-only through the RPC.
alter table public.season_registrations add column if not exists approved_packet_id uuid references public.season_packets(id);

create or replace function public.submit_season_packet(
  p_season_id uuid, p_player_id uuid, p_version text, p_name text, p_dob date,
  p_signer text, p_capacity text, p_guardian_email text, p_guardian_phone text,
  p_emergency_name text, p_emergency_phone text, p_medical_notes text,
  p_risk boolean, p_release boolean, p_emergency boolean, p_concussion boolean,
  p_conduct boolean, p_media boolean
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_player public.players%rowtype; v_id uuid; v_reg public.season_registrations%rowtype;
begin
  if v_user is null then raise exception 'Sign in to register.'; end if;
  select * into v_player from public.players where id=p_player_id and user_id=v_user and deleted_at is null;
  if not found then raise exception 'Player account not found.'; end if;
  if not exists(select 1 from public.seasons where id=p_season_id and is_current) then raise exception 'This season is not open for registration.'; end if;
  if p_version <> 'DTHC-2026-27-v1' then raise exception 'Please refresh to read the current agreement.'; end if;
  if p_name is null or length(trim(p_name))<3 or p_dob is null or p_dob>current_date
    or p_signer is null or length(trim(p_signer))<3 or p_emergency_name is null
    or length(trim(p_emergency_name))<3 or p_emergency_phone is null or length(trim(p_emergency_phone))<7
    or p_risk is distinct from true or p_release is distinct from true
    or p_emergency is distinct from true or p_concussion is distinct from true
    or p_conduct is distinct from true or p_media is null then
    raise exception 'Complete every required section before submitting.';
  end if;
  if p_dob > (current_date - interval '18 years') then
    if p_capacity <> 'parent_or_guardian' or nullif(trim(coalesce(p_guardian_email,'')),'') is null
      or nullif(trim(coalesce(p_guardian_phone,'')),'') is null then
      raise exception 'A parent or legal guardian must complete and sign for a minor.';
    end if;
  elsif p_capacity <> 'self' then raise exception 'Adult participants must sign for themselves.'; end if;
  select * into v_reg from public.season_registrations where season_id=p_season_id and player_id=p_player_id for update;
  if found and v_reg.status='Active' then raise exception 'Your season registration is already approved.'; end if;
  insert into public.season_packets(season_id,player_id,user_id,document_version,participant_name,date_of_birth,
    signer_name,signer_capacity,guardian_email,guardian_phone,emergency_name,emergency_phone,medical_notes,
    risk_accepted,release_accepted,emergency_accepted,concussion_accepted,conduct_accepted,media_consent)
  values(p_season_id,p_player_id,v_user,p_version,trim(p_name),p_dob,trim(p_signer),p_capacity,
    nullif(trim(coalesce(p_guardian_email,'')),''),nullif(trim(coalesce(p_guardian_phone,'')),''),
    trim(p_emergency_name),trim(p_emergency_phone),nullif(trim(coalesce(p_medical_notes,'')),''),
    p_risk,p_release,p_emergency,p_concussion,p_conduct,p_media) returning id into v_id;
  if found and v_reg.id is not null then
    update public.season_registrations set status='Pending',approved_packet_id=null,activated_at=null,activated_by=null,updated_at=now()
    where id=v_reg.id;
  else
    insert into public.season_registrations(season_id,player_id,team,status)
    values(p_season_id,p_player_id,v_player.team,'Pending');
  end if;
  return v_id;
end $$;

create or replace function public.approve_season_packet(p_packet_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_packet public.season_packets%rowtype; v_player public.players%rowtype;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','manager')) then
    raise exception 'Admin or manager access required.';
  end if;
  select * into v_packet from public.season_packets where id=p_packet_id;
  if not found then raise exception 'Signed packet not found.'; end if;
  perform 1 from public.season_registrations
    where season_id=v_packet.season_id and player_id=v_packet.player_id for update;
  if not found then raise exception 'Season registration not found.'; end if;
  if v_packet.document_version <> 'DTHC-2026-27-v1'
    or not (v_packet.risk_accepted and v_packet.release_accepted and v_packet.emergency_accepted
      and v_packet.concussion_accepted and v_packet.conduct_accepted)
    or (v_packet.date_of_birth > (v_packet.signed_at::date - interval '18 years')
      and v_packet.signer_capacity <> 'parent_or_guardian') then
    raise exception 'Required registration items are missing.';
  end if;
  if not exists(select 1 from public.seasons where id=v_packet.season_id and is_current) then
    raise exception 'This is not the current season.';
  end if;
  if exists(select 1 from public.season_packets where season_id=v_packet.season_id and player_id=v_packet.player_id
    and (signed_at,id) > (v_packet.signed_at,v_packet.id)) then
    raise exception 'Review the latest packet instead.';
  end if;
  select * into v_player from public.players where id=v_packet.player_id and deleted_at is null;
  if not found then raise exception 'Player not found.'; end if;
  update public.season_registrations set status='Active',approved_packet_id=v_packet.id,
    activated_at=now(),activated_by=auth.uid(),team=v_player.team,updated_at=now()
  where season_id=v_packet.season_id and player_id=v_packet.player_id;
  if not found then raise exception 'Season registration not found.'; end if;
end $$;

create or replace function public.guard_season_activation() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status='Active' and (tg_op='INSERT' or old.status is distinct from 'Active' or old.approved_packet_id is distinct from new.approved_packet_id) then
    if new.approved_packet_id is null or not exists(
      select 1 from public.season_packets pk where pk.id=new.approved_packet_id
        and pk.season_id=new.season_id and pk.player_id=new.player_id
        and pk.document_version='DTHC-2026-27-v1'
        and pk.risk_accepted and pk.release_accepted and pk.emergency_accepted
        and pk.concussion_accepted and pk.conduct_accepted
    ) then raise exception 'A completed signed season packet is required before activation.'; end if;
  end if;
  return new;
end $$;
drop trigger if exists guard_season_activation on public.season_registrations;
create trigger guard_season_activation before insert or update on public.season_registrations
for each row execute function public.guard_season_activation();
revoke all on function public.submit_season_packet(uuid,uuid,text,text,date,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.submit_season_packet(uuid,uuid,text,text,date,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean) to authenticated;
revoke all on function public.approve_season_packet(uuid) from public,anon;
grant execute on function public.approve_season_packet(uuid) to authenticated;
