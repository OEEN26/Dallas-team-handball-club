revoke all on function public.guard_season_activation() from public,anon,authenticated;
create function youth_internal.bio() returns table(id uuid,user_id uuid,name text,team text,"position" text,jersey_number integer,status text,profile_photo_url text,date_of_birth date,bio text,accomplishments text,tournaments_played text,player_history text,hometown text,years_playing integer,nationality text) language sql stable security definer set search_path='' as $projection$  SELECT p.id,
    p.user_id,
    p.name,
    p.team,
    p."position",
    p.jersey_number,
    p.status,
    pp.profile_photo_url,
        CASE
            WHEN p.user_id = (( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
               FROM public.profiles pr
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
   FROM public.players p
     LEFT JOIN public.player_profiles pp ON pp.player_id = p.id
  WHERE youth_internal.can_view(p.id) AND p.deleted_at IS NULL AND p.player_category = 'Member'::text; $projection$;
revoke all on function youth_internal.bio() from public,anon;
grant execute on function youth_internal.bio() to authenticated;
create or replace view public.player_bio_public with(security_invoker=true) as select * from youth_internal.bio();
create function youth_internal.directory() returns table(id uuid,user_id uuid,name text,team text,"position" text,jersey_number integer,status text,profile_photo_url text) language sql stable security definer set search_path='' as $projection$  SELECT p.id,
    p.user_id,
    p.name,
    p.team,
    p."position",
    p.jersey_number,
    p.status,
    pp.profile_photo_url
   FROM public.players p
     LEFT JOIN public.player_profiles pp ON pp.player_id = p.id
  WHERE youth_internal.can_view(p.id) AND p.deleted_at IS NULL AND (p.player_category = 'Member'::text OR p.user_id = auth.uid()); $projection$;
revoke all on function youth_internal.directory() from public,anon;
grant execute on function youth_internal.directory() to authenticated;
create or replace view public.player_directory_public with(security_invoker=true) as select * from youth_internal.directory();
create policy deny_direct_guardian_invites on youth_internal.guardian_invitations for all to authenticated using(false) with check(false);

