-- Guest records share player IDs and tournament history, but not club jersey assignments.
ALTER TABLE public.players ADD COLUMN player_category text NOT NULL DEFAULT 'Member'
  CHECK (player_category IN ('Member','Guest'));
CREATE SCHEMA IF NOT EXISTS guest_internal;
REVOKE ALL ON SCHEMA guest_internal FROM PUBLIC;
GRANT USAGE ON SCHEMA guest_internal TO anon,authenticated;
CREATE TABLE public.guest_details (
 player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,
 info jsonb NOT NULL DEFAULT '{}'::jsonb,
 uniform_number integer CHECK (uniform_number BETWEEN 1 AND 99),
 uniform_size text CHECK (uniform_size IN ('XS','S','M','L','XL','2XL','3XL')),
 uniform_ownership text NOT NULL DEFAULT 'None' CHECK (uniform_ownership IN ('None','Owned','Borrowed')),
 uniform_return_status text NOT NULL DEFAULT 'Not applicable' CHECK (uniform_return_status IN ('Not applicable','Return pending','Returned')),
 admin_notes text NOT NULL DEFAULT '', updated_at timestamptz NOT NULL DEFAULT now(), updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE TABLE guest_internal.information_links (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 token_hash bytea NOT NULL UNIQUE, expires_at timestamptz NOT NULL, revoked_at timestamptz, used_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE INDEX ON guest_internal.information_links(player_id);
CREATE TABLE public.guest_submissions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 link_id uuid NOT NULL UNIQUE REFERENCES guest_internal.information_links(id) ON DELETE CASCADE,
 info jsonb NOT NULL, status text NOT NULL DEFAULT 'Pending' CHECK(status IN ('Pending','Approved','Rejected')),
 submitted_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz, reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE INDEX ON public.guest_submissions(player_id,status);
CREATE TABLE public.guest_edit_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 action text NOT NULL, changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL, changed_at timestamptz NOT NULL DEFAULT now(),
 before_data jsonb, after_data jsonb
);
CREATE INDEX ON public.guest_edit_history(player_id,changed_at DESC);
ALTER TABLE public.guest_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_internal.information_links ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION guest_internal.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('admin','manager'));
$$;
REVOKE ALL ON FUNCTION guest_internal.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION guest_internal.is_admin() TO authenticated;
CREATE POLICY guest_details_admin_read ON public.guest_details FOR SELECT TO authenticated USING(guest_internal.is_admin());
CREATE POLICY guest_submissions_admin_read ON public.guest_submissions FOR SELECT TO authenticated USING(guest_internal.is_admin());
CREATE POLICY guest_history_admin_read ON public.guest_edit_history FOR SELECT TO authenticated USING(guest_internal.is_admin());
REVOKE ALL ON public.guest_details,public.guest_submissions,public.guest_edit_history FROM anon,authenticated;
GRANT SELECT ON public.guest_details,public.guest_submissions,public.guest_edit_history TO authenticated;
-- A player's own account cannot promote itself or opt into guest privileges.
CREATE FUNCTION guest_internal.guard_category() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (TG_OP='INSERT' AND NEW.player_category='Guest') OR (TG_OP='UPDATE' AND NEW.player_category IS DISTINCT FROM OLD.player_category) THEN
   IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Only club administrators can change player category'; END IF;
 END IF;
 IF NEW.player_category='Guest' AND NEW.jersey_number IS NOT NULL THEN RAISE EXCEPTION 'Use the guest uniform number, not a club jersey assignment'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER guest_category_guard BEFORE INSERT OR UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION guest_internal.guard_category();
-- Preserve the season registration behavior for members; guests register per tournament.
CREATE OR REPLACE FUNCTION public.register_new_player_for_current_season() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.player_category='Member' THEN
  INSERT INTO public.season_registrations(season_id,player_id,team,status)
  SELECT id,NEW.id,NEW.team,'Pending' FROM public.seasons WHERE is_current ON CONFLICT(season_id,player_id) DO NOTHING;
 END IF;
 RETURN NEW;
END; $$;
CREATE FUNCTION guest_internal.clean_info(p_info jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb; k text;
BEGIN
 IF p_info IS NULL OR jsonb_typeof(p_info)<>'object' OR octet_length(p_info::text)>12000 THEN RAISE EXCEPTION 'Invalid guest information'; END IF;
 result='{}'::jsonb;
 FOREACH k IN ARRAY ARRAY['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone'] LOOP
  IF p_info ? k AND jsonb_typeof(p_info->k)<>'string' THEN RAISE EXCEPTION 'Invalid information field'; END IF;
  IF length(coalesce(p_info->>k,''))>300 THEN RAISE EXCEPTION 'Information field is too long'; END IF;
  result=result||jsonb_build_object(k,trim(coalesce(p_info->>k,'')));
 END LOOP;
 IF length(result->>'name')<2 OR result->>'team' NOT IN ('Men','Women') THEN RAISE EXCEPTION 'Enter a name and select a team'; END IF;
 IF result->>'email'<>'' AND result->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Enter a valid email'; END IF;
 IF result->>'position' NOT IN ('','Goalie','Pivot','R. Wing','L. Wing','R. Back','L. Back','Center back') THEN RAISE EXCEPTION 'Choose a playing position'; END IF;
 IF result->>'shirt_size' NOT IN ('','XS','S','M','L','XL','2XL','3XL') THEN RAISE EXCEPTION 'Choose a shirt size'; END IF;
 RETURN result;
END; $$;
CREATE FUNCTION guest_internal.audit_details() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.guest_edit_history(player_id,action,changed_by,before_data,after_data)
 VALUES(NEW.player_id,TG_OP,auth.uid(),CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) ELSE NULL END,to_jsonb(NEW));
 RETURN NEW;
END; $$;
CREATE TRIGGER guest_details_audit AFTER INSERT OR UPDATE ON public.guest_details FOR EACH ROW EXECUTE FUNCTION guest_internal.audit_details();
CREATE FUNCTION guest_internal.save_guest(p_player_id uuid,p_info jsonb,p_uniform jsonb,p_notes text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE info jsonb; playerid uuid; num integer;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 info=guest_internal.clean_info(p_info);
 IF length(coalesce(p_notes,''))>4000 OR octet_length(coalesce(p_uniform,'{}')::text)>1000 THEN RAISE EXCEPTION 'Details too long'; END IF;
 num=nullif(p_uniform->>'number','')::integer;
 IF p_player_id IS NULL THEN
  INSERT INTO public.players(name,team,position,shirt_size,status,player_category)
  VALUES(info->>'name',info->>'team',nullif(info->>'position',''),nullif(info->>'shirt_size',''),'Standby','Guest') RETURNING id INTO playerid;
 ELSE
  SELECT id INTO playerid FROM public.players WHERE id=p_player_id AND player_category='Guest' AND deleted_at IS NULL FOR UPDATE;
  IF playerid IS NULL THEN RAISE EXCEPTION 'Guest record unavailable'; END IF;
  UPDATE public.players SET name=info->>'name',team=info->>'team',position=nullif(info->>'position',''),shirt_size=nullif(info->>'shirt_size','') WHERE id=playerid;
 END IF;
 INSERT INTO public.guest_details(player_id,info,uniform_number,uniform_size,uniform_ownership,uniform_return_status,admin_notes,updated_by)
 VALUES(playerid,info,num,nullif(p_uniform->>'size',''),coalesce(p_uniform->>'ownership','None'),coalesce(p_uniform->>'return_status','Not applicable'),coalesce(p_notes,''),auth.uid())
 ON CONFLICT(player_id) DO UPDATE SET info=EXCLUDED.info,uniform_number=EXCLUDED.uniform_number,uniform_size=EXCLUDED.uniform_size,
 uniform_ownership=EXCLUDED.uniform_ownership,uniform_return_status=EXCLUDED.uniform_return_status,admin_notes=EXCLUDED.admin_notes,updated_by=auth.uid(),updated_at=now();
 RETURN playerid;
END; $$;
CREATE FUNCTION guest_internal.classify_player(p_player_id uuid,p_category text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; d public.guest_details;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 IF p_category NOT IN ('Member','Guest') OR p_category IS NULL THEN RAISE EXCEPTION 'Invalid category'; END IF;
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND deleted_at IS NULL FOR UPDATE;
 IF p.id IS NULL THEN RAISE EXCEPTION 'Player unavailable'; END IF;
 IF p.player_category=p_category THEN RETURN; END IF;
 IF p_category='Guest' THEN
  INSERT INTO public.guest_details(player_id,info,uniform_number,uniform_size,updated_by)
  VALUES(p.id,jsonb_build_object('name',p.name,'team',p.team,'email',coalesce(p.email,''),'phone',coalesce(p.phone,''),'position',coalesce(p.position,''),'shirt_size',coalesce(p.shirt_size,''),'home_club',''),p.jersey_number,CASE WHEN p.shirt_size IN ('XS','S','M','L','XL','2XL','3XL') THEN p.shirt_size ELSE NULL END,auth.uid())
  ON CONFLICT(player_id) DO UPDATE SET info=public.guest_details.info||EXCLUDED.info,uniform_number=coalesce(EXCLUDED.uniform_number,public.guest_details.uniform_number),updated_at=now(),updated_by=auth.uid();
  UPDATE public.players SET player_category='Guest',jersey_number=NULL,email=NULL,phone=NULL WHERE id=p.id;
 ELSE
  SELECT * INTO d FROM public.guest_details WHERE player_id=p.id;
  UPDATE public.players SET player_category='Member',email=nullif(d.info->>'email',''),phone=nullif(d.info->>'phone','') WHERE id=p.id;
  UPDATE guest_internal.information_links SET revoked_at=now() WHERE player_id=p.id AND revoked_at IS NULL;
  INSERT INTO public.season_registrations(season_id,player_id,team,status) SELECT id,p.id,p.team,'Pending' FROM public.seasons WHERE is_current ON CONFLICT(season_id,player_id) DO NOTHING;
 END IF;
 INSERT INTO public.guest_edit_history(player_id,action,changed_by,before_data,after_data)
 VALUES(p.id,'Category changed',auth.uid(),jsonb_build_object('category',p.player_category),jsonb_build_object('category',p_category));
END; $$;
CREATE FUNCTION guest_internal.create_link(p_player_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE token text; linkid uuid; expiry timestamptz=now()+interval '7 days';
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 PERFORM 1 FROM public.players WHERE id=p_player_id AND player_category='Guest' AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Links are only available for guest players'; END IF;
 token=encode(extensions.gen_random_bytes(32),'hex');
 UPDATE guest_internal.information_links SET revoked_at=now() WHERE player_id=p_player_id AND used_at IS NULL AND revoked_at IS NULL;
 INSERT INTO guest_internal.information_links(player_id,token_hash,expires_at,created_by) VALUES(p_player_id,extensions.digest(token,'sha256'),expiry,auth.uid()) RETURNING id INTO linkid;
 RETURN jsonb_build_object('id',linkid,'token',token,'expires_at',expiry);
END; $$;
CREATE FUNCTION guest_internal.manage_links(p_player_id uuid,p_revoke boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 IF p_revoke THEN UPDATE guest_internal.information_links SET revoked_at=now() WHERE player_id=p_player_id AND revoked_at IS NULL; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'expires_at',expires_at,'used_at',used_at,'revoked_at',revoked_at) ORDER BY created_at DESC),'[]') INTO result FROM guest_internal.information_links WHERE player_id=p_player_id;
 RETURN result;
END; $$;
CREATE FUNCTION guest_internal.read_link(p_token text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF p_token IS NULL OR p_token !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 SELECT jsonb_build_object('name',p.name,'info',coalesce(d.info,jsonb_build_object('name',p.name,'team',p.team))) INTO result
 FROM guest_internal.information_links l JOIN public.players p ON p.id=l.player_id LEFT JOIN public.guest_details d ON d.player_id=p.id
 WHERE l.token_hash=extensions.digest(p_token,'sha256') AND l.expires_at>now() AND l.revoked_at IS NULL AND l.used_at IS NULL AND p.player_category='Guest' AND p.deleted_at IS NULL;
 IF result IS NULL THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 RETURN result;
END; $$;
CREATE FUNCTION guest_internal.submit_link(p_token text,p_info jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE l guest_internal.information_links; info jsonb;
BEGIN
 PERFORM guest_internal.read_link(p_token); info=guest_internal.clean_info(p_info);
 SELECT * INTO l FROM guest_internal.information_links WHERE token_hash=extensions.digest(p_token,'sha256') FOR UPDATE;
 IF l.used_at IS NOT NULL OR l.revoked_at IS NOT NULL OR l.expires_at<=now() THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 -- Lock the player too, preventing a concurrent conversion from accepting a member submission.
 PERFORM 1 FROM public.players WHERE id=l.player_id AND player_category='Guest' AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Guest record unavailable'; END IF;
 INSERT INTO public.guest_submissions(player_id,link_id,info) VALUES(l.player_id,l.id,info);
 UPDATE guest_internal.information_links SET used_at=now() WHERE id=l.id;
END; $$;
CREATE FUNCTION guest_internal.review_submission(p_submission_id uuid,p_approve boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.guest_submissions;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 SELECT * INTO s FROM public.guest_submissions WHERE id=p_submission_id AND status='Pending' FOR UPDATE;
 IF s.id IS NULL THEN RAISE EXCEPTION 'Submission already reviewed or unavailable'; END IF;
 PERFORM 1 FROM public.players WHERE id=s.player_id AND player_category='Guest' AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Guest record unavailable'; END IF;
 IF p_approve THEN
  UPDATE public.players SET name=s.info->>'name',team=s.info->>'team',position=nullif(s.info->>'position',''),shirt_size=nullif(s.info->>'shirt_size','') WHERE id=s.player_id;
  INSERT INTO public.guest_details(player_id,info,updated_by) VALUES(s.player_id,s.info,auth.uid()) ON CONFLICT(player_id) DO UPDATE SET info=s.info,updated_at=now(),updated_by=auth.uid();
 END IF;
 UPDATE public.guest_submissions SET status=CASE WHEN p_approve THEN 'Approved' ELSE 'Rejected' END,reviewed_at=now(),reviewed_by=auth.uid() WHERE id=s.id;
 INSERT INTO public.guest_edit_history(player_id,action,changed_by,after_data) VALUES(s.player_id,CASE WHEN p_approve THEN 'Submission approved' ELSE 'Submission rejected' END,auth.uid(),jsonb_build_object('submission_id',s.id));
END; $$;
CREATE FUNCTION guest_internal.add_to_tournament(p_player_id uuid,p_tournament_id uuid,p_jersey_number integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players; conflict_name text;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND deleted_at IS NULL FOR UPDATE;
 IF p.id IS NULL THEN RAISE EXCEPTION 'Player unavailable'; END IF;
 PERFORM 1 FROM public.tournaments WHERE id=p_tournament_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Tournament unavailable'; END IF;
 IF p.player_category='Member' AND NOT EXISTS(SELECT 1 FROM public.season_registrations s JOIN public.seasons se ON se.id=s.season_id WHERE se.is_current AND s.player_id=p.id AND s.status='Active') THEN RAISE EXCEPTION 'Approve the club member for the current season first'; END IF;
 IF p_jersey_number IS NOT NULL AND p_jersey_number NOT BETWEEN 1 AND 99 THEN RAISE EXCEPTION 'Jersey number must be between 1 and 99'; END IF;
 SELECT other.name INTO conflict_name FROM public.tournament_players tp JOIN public.players other ON other.id=tp.player_id
 WHERE tp.tournament_id=p_tournament_id AND tp.player_id<>p.id AND tp.roster_status IN ('Selected','Confirmed') AND coalesce(tp.jersey_number,other.jersey_number)=p_jersey_number LIMIT 1;
 IF conflict_name IS NOT NULL THEN RAISE EXCEPTION 'That tournament jersey is assigned to %. Choose another number.',conflict_name; END IF;
 INSERT INTO public.tournament_players(tournament_id,player_id,roster_status,jersey_number) VALUES(p_tournament_id,p.id,'Selected',p_jersey_number)
 ON CONFLICT(tournament_id,player_id) DO UPDATE SET roster_status='Selected',jersey_number=EXCLUDED.jersey_number,updated_at=now();
END; $$;
-- Public API wrappers retain caller permissions; privileged work stays in an unexposed schema.
CREATE FUNCTION public.admin_save_guest(p_player_id uuid,p_info jsonb,p_uniform jsonb,p_notes text) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.save_guest(p_player_id,p_info,p_uniform,p_notes); $$;
CREATE FUNCTION public.admin_classify_player(p_player_id uuid,p_category text) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.classify_player(p_player_id,p_category); $$;
CREATE FUNCTION public.admin_create_guest_link(p_player_id uuid) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.create_link(p_player_id); $$;
CREATE FUNCTION public.admin_guest_links(p_player_id uuid,p_revoke boolean DEFAULT false) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.manage_links(p_player_id,p_revoke); $$;
CREATE FUNCTION public.guest_information(p_token text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.read_link(p_token); $$;
CREATE FUNCTION public.submit_guest_information(p_token text,p_info jsonb) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.submit_link(p_token,p_info); $$;
CREATE FUNCTION public.admin_review_guest_submission(p_submission_id uuid,p_approve boolean) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.review_submission(p_submission_id,p_approve); $$;
CREATE FUNCTION public.admin_add_tournament_player(p_player_id uuid,p_tournament_id uuid,p_jersey_number integer) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.add_to_tournament(p_player_id,p_tournament_id,p_jersey_number); $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA guest_internal FROM PUBLIC;
GRANT EXECUTE ON FUNCTION guest_internal.is_admin(),guest_internal.save_guest(uuid,jsonb,jsonb,text),guest_internal.classify_player(uuid,text),guest_internal.create_link(uuid),guest_internal.manage_links(uuid,boolean),guest_internal.review_submission(uuid,boolean),guest_internal.add_to_tournament(uuid,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION guest_internal.read_link(text),guest_internal.submit_link(text,jsonb) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_save_guest(uuid,jsonb,jsonb,text),public.admin_classify_player(uuid,text),public.admin_create_guest_link(uuid),public.admin_guest_links(uuid,boolean),public.admin_review_guest_submission(uuid,boolean),public.admin_add_tournament_player(uuid,uuid,integer),public.guest_information(text),public.submit_guest_information(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_guest(uuid,jsonb,jsonb,text),public.admin_classify_player(uuid,text),public.admin_create_guest_link(uuid),public.admin_guest_links(uuid,boolean),public.admin_review_guest_submission(uuid,boolean),public.admin_add_tournament_player(uuid,uuid,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guest_information(text),public.submit_guest_information(text,jsonb) TO anon,authenticated;

-- Keep public club directories focused on members without changing their existing view permissions.
DO $$ DECLARE definition text; BEGIN
 definition=pg_get_viewdef('public.player_bio_public'::regclass,true);
 IF definition NOT LIKE '%player_category%' THEN
  definition=replace(definition,'WHERE p.deleted_at IS NULL','WHERE p.deleted_at IS NULL AND p.player_category = ''Member''');
  EXECUTE 'CREATE OR REPLACE VIEW public.player_bio_public AS '||definition;
 END IF;
END; $$;
CREATE OR REPLACE FUNCTION guest_internal.guard_category() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (TG_OP='INSERT' AND NEW.player_category='Guest') OR (TG_OP='UPDATE' AND (NEW.player_category IS DISTINCT FROM OLD.player_category OR OLD.player_category='Guest')) THEN
   IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Only club administrators can edit guest records or change player category'; END IF;
 END IF;
 IF NEW.player_category='Guest' AND NEW.jersey_number IS NOT NULL THEN RAISE EXCEPTION 'Use the guest uniform number, not a club jersey assignment'; END IF;
 RETURN NEW;
END; $$;

DO $$ DECLARE definition text; BEGIN definition=pg_get_viewdef('public.player_directory_public'::regclass,true); IF definition NOT LIKE '%player_category%' THEN definition=replace(definition,'WHERE p.deleted_at IS NULL','WHERE p.deleted_at IS NULL AND (p.player_category = ''Member'' OR p.user_id = auth.uid())'); EXECUTE 'CREATE OR REPLACE VIEW public.player_directory_public AS '||definition; END IF; END; $$;
