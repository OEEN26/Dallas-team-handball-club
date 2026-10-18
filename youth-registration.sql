-- Guardian-managed youth registration. Public RPCs delegate to a non-exposed schema.
create schema if not exists youth_internal;
revoke all on schema youth_internal from public,anon;
grant usage on schema youth_internal to authenticated;
alter table public.players drop constraint players_team_check;
alter table public.players add constraint players_team_check check(team in ('Men','Women','Youth'));
-- Existing season registration uses the same team vocabulary.
do $$ declare c record; begin
 for c in select conname from pg_constraint where conrelid='public.season_registrations'::regclass and contype='c' and pg_get_constraintdef(oid) like '%team%' loop
  execute format('alter table public.season_registrations drop constraint %I',c.conname);
 end loop;
end $$;
alter table public.season_registrations add constraint season_registration_team_check check(team in ('Men','Women','Youth'));
create table public.youth_registrations(
 player_id uuid primary key references public.players(id) on delete cascade,
 date_of_birth date not null check(date_of_birth<=current_date),
 division text not null check(division in ('Under 12','12–14','15–17')),
 guardian_user_id uuid references auth.users(id) on delete set null,
 guardian_name text, guardian_relationship text, guardian_email text, guardian_phone text,
 guardian_attested_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index youth_guardian_idx on public.youth_registrations(guardian_user_id);
alter table public.youth_registrations enable row level security;
revoke all on public.youth_registrations from public,anon,authenticated;
grant select on public.youth_registrations to authenticated;
create function youth_internal.is_staff() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','manager'));
$$;
create function youth_internal.is_guardian(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.youth_registrations where player_id=p_id and guardian_user_id=auth.uid());
$$;
create function youth_internal.can_view(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (youth_internal.is_staff() or youth_internal.is_guardian(p_id) or not exists(select 1 from public.youth_registrations where player_id=p_id));
$$;
create policy youth_owner_staff_read on public.youth_registrations for select to authenticated using(guardian_user_id=(select auth.uid()) or (select youth_internal.is_staff()));
create policy guardian_reads_player on public.players for select to authenticated using(youth_internal.is_guardian(id));

create table youth_internal.guardian_invitations(
 token_hash text primary key, player_id uuid not null references public.youth_registrations(player_id) on delete cascade,
 email text not null,expires_at timestamptz not null default now()+interval '7 days',used_at timestamptz,created_by uuid not null references auth.users(id)
);
alter table youth_internal.guardian_invitations enable row level security;
revoke all on youth_internal.guardian_invitations from public,anon,authenticated;

create function youth_internal.register_player(p_first text,p_last text,p_dob date,p_guardian text,p_relationship text,p_phone text,p_confirm boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare u auth.users%rowtype; pid uuid; division text;
begin
 select * into u from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if u.id is null then raise exception 'Sign in with your verified parent or guardian email.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u.id::text,18));
 if p_confirm is distinct from true or length(btrim(coalesce(p_guardian,'')))<3 or length(btrim(coalesce(p_relationship,'')))<2 or length(btrim(coalesce(p_phone,'')))<7 then raise exception 'An adult parent or legal guardian must confirm their role and provide contact details.'; end if;
 if length(btrim(coalesce(p_first,'')))<1 or length(btrim(coalesce(p_last,'')))<1 or length(p_first)>150 or length(p_last)>150 or length(p_guardian)>300 or length(p_phone)>40 or length(p_relationship)>100 then raise exception 'Enter the participant’s first and last name and valid guardian details.'; end if;
 if p_dob is null or p_dob>current_date or p_dob<=(current_date-interval '18 years')::date then raise exception 'Youth registration is for participants under 18. Adults use player registration.'; end if;
 if exists(select 1 from public.youth_registrations y join public.players p on p.id=y.player_id where y.guardian_user_id=u.id and y.date_of_birth=p_dob and lower(p.name)=lower(btrim(p_first)||' '||btrim(p_last)) and p.deleted_at is null) then raise exception 'This child is already registered. Use their existing card below.'; end if;
 division:=case when p_dob>(current_date-interval '12 years')::date then 'Under 12' when p_dob>(current_date-interval '15 years')::date then '12–14' else '15–17' end;
 insert into public.players(name,team,status,player_category,tournament_roster) values(btrim(p_first)||' '||btrim(p_last),'Youth','Inactive','Member',false) returning id into pid;
 insert into public.youth_registrations(player_id,date_of_birth,division,guardian_user_id,guardian_name,guardian_relationship,guardian_email,guardian_phone,guardian_attested_at)
 values(pid,p_dob,division,u.id,btrim(p_guardian),btrim(p_relationship),lower(u.email),btrim(p_phone),now());
 return pid;
end $$;
create function public.register_youth_player(p_first text,p_last text,p_dob date,p_guardian text,p_relationship text,p_phone text,p_confirm boolean)
returns uuid language sql security invoker set search_path='' as $$ select youth_internal.register_player(p_first,p_last,p_dob,p_guardian,p_relationship,p_phone,p_confirm); $$;

create function youth_internal.invite_guardian(p_player_id uuid,p_email text) returns text language plpgsql security definer set search_path='' as $$
declare token text;
begin
 if not youth_internal.is_staff() then raise exception 'Club staff access required.'; end if;
 if p_email is null or length(p_email)>254 or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter the parent or guardian email.'; end if;
 perform 1 from public.youth_registrations y join public.players p on p.id=y.player_id where y.player_id=p_player_id and p.deleted_at is null and y.guardian_user_id is null for update of y;
 if not found then raise exception 'Youth player unavailable or a guardian is already linked. Contact an admin for guardian changes.'; end if;
 update youth_internal.guardian_invitations set used_at=now() where player_id=p_player_id and used_at is null;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into youth_internal.guardian_invitations(token_hash,player_id,email,created_by) values(encode(extensions.digest(token,'sha256'),'hex'),p_player_id,lower(btrim(p_email)),auth.uid());
 return token;
end $$;
create function public.invite_youth_guardian(p_player_id uuid,p_email text) returns text language sql security invoker set search_path='' as $$ select youth_internal.invite_guardian(p_player_id,p_email); $$;
create function youth_internal.claim_guardian(p_token text,p_guardian text,p_relationship text,p_phone text,p_confirm boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare u auth.users%rowtype; invite youth_internal.guardian_invitations%rowtype;
begin
 select * into u from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if u.id is null then raise exception 'Sign in with the verified guardian email the invitation was created for.'; end if;
 if p_confirm is distinct from true or length(btrim(coalesce(p_guardian,'')))<3 or length(btrim(coalesce(p_relationship,'')))<2 or length(btrim(coalesce(p_phone,'')))<7 or length(p_guardian)>300 or length(p_relationship)>100 or length(p_phone)>40 then raise exception 'Confirm that you are an adult parent or legal guardian and enter your contact details.'; end if;
 select * into invite from youth_internal.guardian_invitations where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and used_at is null and expires_at>now() and email=lower(u.email) for update;
 if not found then raise exception 'Invitation invalid, expired, already used, or intended for another email.'; end if;
 perform 1 from public.youth_registrations where player_id=invite.player_id and guardian_user_id is null for update;
 if not found then raise exception 'A guardian is already linked. Contact the club admin.'; end if;
 update public.youth_registrations set guardian_user_id=u.id,guardian_name=btrim(p_guardian),guardian_relationship=btrim(p_relationship),guardian_email=lower(u.email),guardian_phone=btrim(p_phone),guardian_attested_at=now(),updated_at=now() where player_id=invite.player_id;
 update public.season_registrations set status='Pending',approved_packet_id=null,activated_at=null,activated_by=null where player_id=invite.player_id and season_id in(select id from public.seasons where is_current);
 update public.players set user_id=null,status='Inactive' where id=invite.player_id;
 update youth_internal.guardian_invitations set used_at=now() where token_hash=invite.token_hash;
 return invite.player_id;
end $$;
create function public.claim_youth_guardian(p_token text,p_guardian text,p_relationship text,p_phone text,p_confirm boolean) returns uuid language sql security invoker set search_path='' as $$ select youth_internal.claim_guardian(p_token,p_guardian,p_relationship,p_phone,p_confirm); $$;

-- Every youth signature must be tied to the child's recorded DOB and verified guardian account.
create function youth_internal.validate_signature() returns trigger language plpgsql security definer set search_path='' as $$
declare y public.youth_registrations%rowtype; email text;
begin
 select * into y from public.youth_registrations where player_id=new.player_id;
 if found then
  select lower(u.email) into email from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null;
  if y.guardian_user_id is distinct from auth.uid() or auth.uid() is null or y.guardian_attested_at is null or new.user_id is distinct from y.guardian_user_id or email is null or email<>y.guardian_email or new.date_of_birth<>y.date_of_birth or new.participant_name<>(select name from public.players where id=new.player_id) or new.signer_capacity is distinct from 'parent_or_guardian' or lower(btrim(coalesce(new.guardian_email,'')))<>email or btrim(new.signer_name)<>y.guardian_name then raise exception 'The verified parent or guardian must personally sign using the recorded name, email, and child’s birth date.'; end if;
 elsif new.date_of_birth>(current_date-interval '18 years')::date then
  raise exception 'Use Youth & family registration. An admin can link an existing youth profile to its guardian.';
 end if;
 return new;
end $$;
create trigger youth_packet_signature before insert on public.season_packets for each row execute function youth_internal.validate_signature();
create trigger youth_agreement_signature before insert on public.season_player_agreements for each row execute function youth_internal.validate_signature();

create function youth_internal.guard_player() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.youth_registrations where player_id=new.id) then
  if new.team<>'Youth' or new.player_category<>'Member' or new.tournament_roster then raise exception 'Youth profiles stay in the Youth group and cannot join the adult roster.'; end if;
  if new.status='Active' and (tg_op='INSERT' or old.status is distinct from 'Active') and not exists(select 1 from public.season_registrations r join public.seasons s on s.id=r.season_id where r.player_id=new.id and r.status='Active' and s.is_current and r.approved_packet_id is not null) then raise exception 'Review and approve the guardian’s current season packet before activating this youth player.'; end if;
  if tg_op='UPDATE' and new.user_id is distinct from old.user_id and new.user_id is not null then raise exception 'Manage youth through the parent or guardian account.'; end if;
 end if;
 return new;
end $$;
create trigger youth_guard_player before insert or update on public.players for each row execute function youth_internal.guard_player();
create function youth_internal.record_minor() returns trigger language plpgsql security definer set search_path='' as $$
declare y public.youth_registrations%rowtype;
begin
 select * into y from public.youth_registrations where player_id=new.player_id;
 if found and new.date_of_birth is distinct from y.date_of_birth then raise exception 'Contact an admin to correct a youth birth date; it cannot be changed through the adult profile.'; end if;
 if new.date_of_birth>(current_date-interval '18 years')::date and y.player_id is null then
  insert into public.youth_registrations(player_id,date_of_birth,division) values(new.player_id,new.date_of_birth,case when new.date_of_birth>(current_date-interval '12 years')::date then 'Under 12' when new.date_of_birth>(current_date-interval '15 years')::date then '12–14' else '15–17' end);
  update public.players set team='Youth',status='Inactive',tournament_roster=false where id=new.player_id;
 end if;
 return new;
end $$;
create trigger youth_record_minor before insert or update of date_of_birth on public.player_profiles for each row execute function youth_internal.record_minor();

-- Adopt existing minors without guessing that a child's account belongs to a guardian.
insert into public.youth_registrations(player_id,date_of_birth,division)
select p.id,d.dob,case when d.dob>(current_date-interval '12 years')::date then 'Under 12' when d.dob>(current_date-interval '15 years')::date then '12–14' else '15–17' end
from public.players p cross join lateral (select max(dob) as dob from (select date_of_birth as dob from public.player_profiles where player_id=p.id union all select date_of_birth from public.season_packets where player_id=p.id) b) d
where d.dob>(current_date-interval '18 years')::date and p.player_category='Member' and p.deleted_at is null;
update public.players p set team='Youth',status='Inactive',tournament_roster=false where exists(select 1 from public.youth_registrations y where y.player_id=p.id);
update public.season_registrations r set team='Youth',status='Pending',approved_packet_id=null,activated_by=null,activated_at=null where exists(select 1 from public.youth_registrations y where y.player_id=r.player_id);

-- Limit shared youth visibility, including legacy views that intentionally publish adult bios.
CREATE OR REPLACE FUNCTION public.submit_season_packet(p_season_id uuid, p_player_id uuid, p_version text, p_name text, p_dob date, p_signer text, p_capacity text, p_guardian_email text, p_guardian_phone text, p_emergency_name text, p_emergency_phone text, p_medical_notes text, p_risk boolean, p_release boolean, p_emergency boolean, p_concussion boolean, p_conduct boolean, p_media boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid := auth.uid(); v_player public.players%rowtype; v_id uuid; v_reg public.season_registrations%rowtype;
begin
  if v_user is null then raise exception 'Sign in to register.'; end if;
  select * into v_player from public.players where id=p_player_id and (user_id=v_user or youth_internal.is_guardian(id)) and deleted_at is null;
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
end $function$
;
CREATE OR REPLACE FUNCTION inventory_internal.sign_season_player_agreement(p_season_id uuid, p_player_id uuid, p_version text, p_dob date, p_signer text, p_capacity text, p_guardian_email text, p_guardian_phone text, p_accepted boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p public.players%rowtype; s public.seasons%rowtype; d public.season_agreement_documents%rowtype; known_dob date; signature_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in to sign the player agreement.'; END IF;
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND (user_id=auth.uid() OR youth_internal.is_guardian(id)) AND deleted_at IS NULL AND player_category='Member' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Your club member profile was not found.'; END IF;
 SELECT * INTO s FROM public.seasons WHERE id=p_season_id AND is_current FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'This is not the current season.'; END IF;
 IF p_version IS DISTINCT FROM 'DTHC-PLAYER-COMMITMENT-v1' THEN RAISE EXCEPTION 'Refresh to read the current player agreement.'; END IF;
 SELECT * INTO d FROM public.season_agreement_documents WHERE version=p_version;
 IF NOT FOUND THEN RAISE EXCEPTION 'Agreement document unavailable.'; END IF;
 IF p_accepted IS DISTINCT FROM true OR nullif(trim(p_signer),'') IS NULL OR length(trim(p_signer))<3 OR length(p_signer)>300 OR p_dob IS NULL OR p_dob>current_date THEN RAISE EXCEPTION 'Read and acknowledge the agreement, enter a valid birth date, and sign your full legal name.'; END IF;
 SELECT date_of_birth INTO known_dob FROM public.season_packets WHERE player_id=p.id ORDER BY signed_at DESC,id DESC LIMIT 1;
 IF known_dob IS NULL THEN SELECT date_of_birth INTO known_dob FROM public.player_profiles WHERE player_id=p.id; END IF;
 IF known_dob IS NULL THEN SELECT date_of_birth INTO known_dob FROM public.youth_registrations WHERE player_id=p.id; END IF;
 IF known_dob IS NOT NULL AND known_dob<>p_dob THEN RAISE EXCEPTION 'Birth date must match the date recorded in your waiver or player profile.'; END IF;
 IF p_dob>(current_date-interval '18 years') THEN
  IF p_capacity IS DISTINCT FROM 'parent_or_guardian' OR nullif(trim(p_guardian_email),'') IS NULL OR nullif(trim(p_guardian_phone),'') IS NULL OR length(trim(p_guardian_phone))<7 OR position('@' IN p_guardian_email)<2 THEN RAISE EXCEPTION 'A parent or legal guardian must sign for a minor and provide contact details.'; END IF;
 ELSE
  IF p_capacity IS DISTINCT FROM 'self' THEN RAISE EXCEPTION 'Adult players must sign for themselves.'; END IF;
 END IF;
 INSERT INTO public.season_player_agreements(season_id,player_id,user_id,document_version,document_title,document_body,season_name,participant_name,date_of_birth,signer_name,signer_capacity,guardian_email,guardian_phone,accepted)
 VALUES(s.id,p.id,auth.uid(),d.version,d.title,d.body,s.name,p.name,p_dob,trim(p_signer),p_capacity,CASE WHEN p_capacity='parent_or_guardian' THEN trim(p_guardian_email) END,CASE WHEN p_capacity='parent_or_guardian' THEN trim(p_guardian_phone) END,true)
 ON CONFLICT(season_id,player_id,document_version) DO NOTHING RETURNING id INTO signature_id;
 IF signature_id IS NULL THEN SELECT id INTO signature_id FROM public.season_player_agreements WHERE season_id=s.id AND player_id=p.id AND document_version=d.version; END IF;
 RETURN signature_id;
END $function$
;
CREATE OR REPLACE FUNCTION public.guard_season_activation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.status='Active' and (tg_op='INSERT' or old.status is distinct from 'Active' or old.approved_packet_id is distinct from new.approved_packet_id) then
    if exists(select 1 from public.youth_registrations where player_id=new.player_id) then
      if not exists(
       select 1 from public.youth_registrations y
       join public.season_packets pk on pk.id=new.approved_packet_id and pk.player_id=y.player_id and pk.season_id=new.season_id
       join public.season_player_agreements a on a.player_id=y.player_id and a.season_id=new.season_id and a.document_version='DTHC-PLAYER-COMMITMENT-v1' and a.accepted
       join auth.users u on u.id=y.guardian_user_id and u.email_confirmed_at is not null
       where y.player_id=new.player_id and y.guardian_attested_at is not null
       and pk.user_id=y.guardian_user_id and a.user_id=y.guardian_user_id
       and pk.signer_capacity='parent_or_guardian' and a.signer_capacity='parent_or_guardian'
       and pk.date_of_birth=y.date_of_birth and a.date_of_birth=y.date_of_birth
       and lower(pk.guardian_email)=lower(u.email) and lower(a.guardian_email)=lower(u.email)
       and pk.signer_name=y.guardian_name and a.signer_name=y.guardian_name
      ) then raise exception 'Guardian approval is incomplete. Review the verified guardian’s waiver and player agreement first.'; end if;
      if exists(select 1 from public.season_packets pk join public.season_packets chosen on chosen.id=new.approved_packet_id where pk.player_id=new.player_id and pk.season_id=new.season_id and (pk.signed_at,pk.id)>(chosen.signed_at,chosen.id)) then raise exception 'Review the latest guardian packet.'; end if;
    end if;
    if not exists(select 1 from public.season_player_agreements a where a.season_id=new.season_id and a.player_id=new.player_id and a.document_version='DTHC-PLAYER-COMMITMENT-v1' and a.accepted) then raise exception 'The player must sign the Season Player Commitment Agreement before season activation.'; end if;
    if new.approved_packet_id is null or not exists(
      select 1 from public.season_packets pk where pk.id=new.approved_packet_id
        and pk.season_id=new.season_id and pk.player_id=new.player_id
        and pk.document_version='DTHC-2026-27-v1'
        and pk.risk_accepted and pk.release_accepted and pk.emergency_accepted
        and pk.concussion_accepted and pk.conduct_accepted
    ) then raise exception 'A completed signed season packet is required before activation.'; end if;
  end if;
  return new;
end $function$
;
create or replace view public.player_bio_public as  SELECT p.id,
    p.user_id,
    p.name,
    p.team,
    p."position",
    p.jersey_number,
    p.status,
    pp.profile_photo_url,
        CASE
            WHEN p.user_id = (( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
               FROM profiles pr
              WHERE pr.id = (( SELECT auth.uid() AS uid)) AND (pr.role = ANY (ARRAY['admin'::text, 'manager'::text])))) THEN pp.date_of_birth
            ELSE NULL::date
        END AS date_of_birth,
    pp.bio,
    pp.accomplishments,
    pp.tournaments_played,
    pp.player_history,
    pp.hometown,
    pp.years_playing,
    pp.nationality
   FROM players p
     LEFT JOIN player_profiles pp ON pp.player_id = p.id
  WHERE youth_internal.can_view(p.id) AND p.deleted_at IS NULL AND p.player_category = 'Member'::text;
create or replace view public.player_directory_public as  SELECT p.id,
    p.user_id,
    p.name,
    p.team,
    p."position",
    p.jersey_number,
    p.status,
    pp.profile_photo_url
   FROM players p
     LEFT JOIN player_profiles pp ON pp.player_id = p.id
  WHERE youth_internal.can_view(p.id) AND p.deleted_at IS NULL AND (p.player_category = 'Member'::text OR p.user_id = auth.uid());
CREATE OR REPLACE FUNCTION public.tournament_public_roster(p_tournament_id uuid)
 RETURNS TABLE(player_id uuid, player_name text, jersey_number integer, roster_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null or not exists (select 1 from public.tournaments t where t.id = p_tournament_id) then
    raise exception 'Tournament unavailable';
  end if;
  return query
    select tp.player_id, p.name::text, coalesce(tp.jersey_number,p.jersey_number), tp.roster_status::text
    from public.tournament_players tp
    join public.players p on p.id = tp.player_id
    where tp.tournament_id = p_tournament_id
      and tp.roster_status in ('Interested','Selected','Confirmed')
      and p.deleted_at is null and youth_internal.can_view(p.id)
    order by case tp.roster_status when 'Confirmed' then 0 when 'Selected' then 1 else 2 end, p.name;
end;
$function$
;

create policy guardian_reads_season_registration on public.season_registrations for select to authenticated using(youth_internal.is_guardian(player_id));
create policy youth_gallery_visibility on public.player_gallery as restrictive for select to authenticated using(youth_internal.can_view(player_id));
create policy youth_jersey_history_visibility on public.jersey_history as restrictive for select to authenticated using(youth_internal.can_view(player_id));
-- Record the original participant account so it cannot appear in a shared account directory.
alter table public.youth_registrations add column participant_user_id uuid references auth.users(id) on delete set null;
update public.youth_registrations y set participant_user_id=p.user_id from public.players p where p.id=y.player_id;
create function youth_internal.can_view_account(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (p_user=auth.uid() or youth_internal.is_staff() or not exists(select 1 from public.youth_registrations where participant_user_id=p_user));
$$;
create policy youth_account_privacy on public.profiles as restrictive for select to authenticated using(youth_internal.can_view_account(id));
-- Any later birth-date identification must also retain the participant account marker.
create or replace function youth_internal.record_minor() returns trigger language plpgsql security definer set search_path='' as $$
declare y public.youth_registrations%rowtype;
begin
 select * into y from public.youth_registrations where player_id=new.player_id;
 if found and new.date_of_birth is distinct from y.date_of_birth then raise exception 'Contact an admin to correct a youth birth date; it cannot be changed through the adult profile.'; end if;
 if new.date_of_birth>(current_date-interval '18 years')::date and y.player_id is null then
  insert into public.youth_registrations(player_id,date_of_birth,division,participant_user_id) select new.player_id,new.date_of_birth,case when new.date_of_birth>(current_date-interval '12 years')::date then 'Under 12' when new.date_of_birth>(current_date-interval '15 years')::date then '12–14' else '15–17' end,user_id from public.players where id=new.player_id;
  update public.players set team='Youth',status='Inactive',tournament_roster=false where id=new.player_id;
 end if;
 return new;
end $$;
-- The ordinary guest link remains for adults; youth use the authenticated guardian process.
create function guest_internal.require_adult_birth_date(p_info jsonb) returns void language plpgsql security invoker set search_path='' as $$
declare dob date;
begin
 begin dob:=(p_info->>'date_of_birth')::date; exception when others then raise exception 'Enter a valid participant birth date.'; end;
 if dob is null or dob>current_date then raise exception 'Enter a valid participant birth date.'; end if;
 if dob>(current_date-interval '18 years')::date then raise exception 'Players under 18 must use Youth & family registration with a parent or legal guardian.'; end if;
end $$;
revoke all on function guest_internal.require_adult_birth_date(jsonb) from public;
grant execute on function guest_internal.require_adult_birth_date(jsonb) to anon,authenticated;
create or replace function public.submit_guest_registration(p_token text,p_info jsonb) returns void language plpgsql security invoker set search_path='' as $$ begin perform guest_internal.require_adult_birth_date(p_info); perform guest_internal.submit_registration(p_token,p_info-'date_of_birth'); end $$;
create or replace function public.submit_guest_information(p_token text,p_info jsonb) returns void language plpgsql security invoker set search_path='' as $$ begin perform guest_internal.require_adult_birth_date(p_info); perform guest_internal.submit_link(p_token,p_info-'date_of_birth'); end $$;
-- Explicit function grants: no anonymous access to guardian data or write operations.
revoke all on all functions in schema youth_internal from public,anon,authenticated;
grant execute on function youth_internal.is_staff(),youth_internal.is_guardian(uuid),youth_internal.can_view(uuid),youth_internal.can_view_account(uuid),youth_internal.register_player(text,text,date,text,text,text,boolean),youth_internal.invite_guardian(uuid,text),youth_internal.claim_guardian(text,text,text,text,boolean) to authenticated;
revoke all on function public.register_youth_player(text,text,date,text,text,text,boolean),public.invite_youth_guardian(uuid,text),public.claim_youth_guardian(text,text,text,text,boolean) from public,anon;
grant execute on function public.register_youth_player(text,text,date,text,text,text,boolean),public.invite_youth_guardian(uuid,text),public.claim_youth_guardian(text,text,text,text,boolean) to authenticated;
create function youth_internal.sync_activation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.youth_registrations where player_id=new.player_id) and exists(select 1 from public.seasons where id=new.season_id and is_current) then
  update public.players set status=case when new.status='Active' then 'Active' else 'Inactive' end where id=new.player_id and status is distinct from case when new.status='Active' then 'Active' else 'Inactive' end;
 end if;
 return new;
end $$;
revoke all on function youth_internal.sync_activation() from public,anon,authenticated;
create trigger youth_sync_activation after insert or update of status on public.season_registrations for each row execute function youth_internal.sync_activation();

create policy youth_profile_insert_guard on public.player_profiles as restrictive for insert to authenticated with check (not exists(select 1 from public.youth_registrations y where y.player_id=player_profiles.player_id));
create policy youth_private_insert_guard on public.player_private_details as restrictive for insert to authenticated with check (youth_internal.can_view(player_id));
-- A supplied user_id alone must never authorize adding details to another player's record.
create policy profile_insert_ownership on public.player_profiles as restrictive for insert to authenticated with check(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff()))));
create policy profile_update_ownership on public.player_profiles as restrictive for update to authenticated using(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff())))) with check(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff()))));
create policy private_insert_ownership on public.player_private_details as restrictive for insert to authenticated with check(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff()))));
create policy private_update_ownership on public.player_private_details as restrictive for update to authenticated using(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff())))) with check(exists(select 1 from public.players p where p.id=player_id and (p.user_id=(select auth.uid()) or (select youth_internal.is_staff()))));
