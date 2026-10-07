-- Private, single-use invitations for guests who do not yet have a player record.
CREATE TABLE guest_internal.registration_links (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), token_hash bytea NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL, used_at timestamptz,
 created_by uuid REFERENCES auth.users(id), created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE guest_internal.registration_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON guest_internal.registration_links FROM PUBLIC,anon,authenticated;
CREATE TABLE public.guest_registrations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), link_id uuid NOT NULL UNIQUE REFERENCES guest_internal.registration_links(id),
 info jsonb NOT NULL, status text NOT NULL DEFAULT 'Pending' CHECK(status IN ('Pending','Approved','Rejected')),
 player_id uuid REFERENCES public.players(id), submitted_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz, reviewed_by uuid REFERENCES auth.users(id)
);
ALTER TABLE public.guest_registrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guest_registrations FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.guest_registrations TO authenticated;
CREATE POLICY guest_registration_admin_read ON public.guest_registrations FOR SELECT TO authenticated USING(guest_internal.is_admin());
CREATE FUNCTION guest_internal.create_registration_link() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE token text; expiration timestamptz=now()+interval '7 days';
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 token=encode(extensions.gen_random_bytes(32),'hex');
 INSERT INTO guest_internal.registration_links(token_hash,expires_at,created_by) VALUES(extensions.digest(token,'sha256'),expiration,auth.uid());
 RETURN jsonb_build_object('token',token,'expires_at',expiration);
END; $$;
CREATE FUNCTION guest_internal.registration_information(p_token text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_token IS NULL OR p_token !~ '^[a-f0-9]{64}$' OR NOT EXISTS(SELECT 1 FROM guest_internal.registration_links WHERE token_hash=extensions.digest(p_token,'sha256') AND expires_at>now() AND used_at IS NULL) THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 RETURN jsonb_build_object('info',jsonb_build_object('team','Men'));
END; $$;
CREATE FUNCTION guest_internal.submit_registration(p_token text,p_info jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE linkid uuid; info jsonb;
BEGIN
 IF p_token IS NULL OR p_token !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 info=guest_internal.clean_info(p_info);
 UPDATE guest_internal.registration_links SET used_at=now() WHERE token_hash=extensions.digest(p_token,'sha256') AND expires_at>now() AND used_at IS NULL RETURNING id INTO linkid;
 IF linkid IS NULL THEN RAISE EXCEPTION 'Link is invalid, expired, or already used'; END IF;
 INSERT INTO public.guest_registrations(link_id,info) VALUES(linkid,info);
END; $$;
CREATE FUNCTION guest_internal.review_registration(p_registration_id uuid,p_approve boolean) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.guest_registrations; playerid uuid;
BEGIN
 IF NOT guest_internal.is_admin() THEN RAISE EXCEPTION 'Admin access required'; END IF;
 SELECT * INTO r FROM public.guest_registrations WHERE id=p_registration_id AND status='Pending' FOR UPDATE;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Registration already reviewed or unavailable'; END IF;
 IF p_approve THEN playerid=guest_internal.save_guest(NULL,r.info,'{}'::jsonb,''); END IF;
 UPDATE public.guest_registrations SET status=CASE WHEN p_approve THEN 'Approved' ELSE 'Rejected' END,player_id=playerid,reviewed_at=now(),reviewed_by=auth.uid() WHERE id=r.id;
 RETURN playerid;
END; $$;
CREATE FUNCTION public.admin_create_guest_registration_link() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.create_registration_link(); $$;
CREATE FUNCTION public.guest_registration_information(p_token text) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.registration_information(p_token); $$;
CREATE FUNCTION public.submit_guest_registration(p_token text,p_info jsonb) RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.submit_registration(p_token,p_info); $$;
CREATE FUNCTION public.admin_review_guest_registration(p_registration_id uuid,p_approve boolean) RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT guest_internal.review_registration(p_registration_id,p_approve); $$;
REVOKE ALL ON FUNCTION guest_internal.create_registration_link(),guest_internal.registration_information(text),guest_internal.submit_registration(text,jsonb),guest_internal.review_registration(uuid,boolean),public.admin_create_guest_registration_link(),public.guest_registration_information(text),public.submit_guest_registration(text,jsonb),public.admin_review_guest_registration(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION guest_internal.create_registration_link(),guest_internal.review_registration(uuid,boolean),public.admin_create_guest_registration_link(),public.admin_review_guest_registration(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION guest_internal.registration_information(text),guest_internal.submit_registration(text,jsonb),public.guest_registration_information(text),public.submit_guest_registration(text,jsonb) TO anon,authenticated;
