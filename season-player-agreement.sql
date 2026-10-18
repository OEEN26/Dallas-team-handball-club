CREATE TABLE public.season_agreement_documents (
 version text PRIMARY KEY, title text NOT NULL, body text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.season_agreement_documents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.season_agreement_documents FROM anon,authenticated;
GRANT SELECT ON public.season_agreement_documents TO anon,authenticated;
CREATE POLICY published_agreement_text ON public.season_agreement_documents FOR SELECT TO anon,authenticated USING(true);
INSERT INTO public.season_agreement_documents(version,title,body) VALUES('DTHC-PLAYER-COMMITMENT-v1','Dallas Team Handball Club — Season Player Commitment Agreement','For the season identified in my registration, I agree to represent Dallas Team Handball Club in tournaments in which Dallas participates, subject to roster selection, eligibility, and my availability.

If Dallas does not participate in a tournament, I may play for another team, subject to applicable tournament and federation rules.

If Dallas participates in the same tournament, I will not represent another team without prior written approval from Dallas team management. This includes situations in which I am not selected for Dallas’s roster; I may request an exception.

Dallas will communicate its confirmed participation before expecting players to make a team commitment. If I have already committed elsewhere before that notice, I will inform management so the situation can be reviewed.

If management determines, after notifying me and allowing me to respond, that I violated this agreement, I will be suspended from Dallas practices and club events for the remainder of that season unless management grants a written exception or reinstatement.

This agreement does not require me to attend every tournament or guarantee selection, playing time, or a roster position.');
CREATE TABLE public.season_player_agreements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), season_id uuid NOT NULL REFERENCES public.seasons(id),
 player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 document_version text NOT NULL REFERENCES public.season_agreement_documents(version),
 document_title text NOT NULL, document_body text NOT NULL, season_name text NOT NULL,
 participant_name text NOT NULL, date_of_birth date NOT NULL CHECK(date_of_birth<=current_date),
 signer_name text NOT NULL, signer_capacity text NOT NULL CHECK(signer_capacity IN ('self','parent_or_guardian')),
 guardian_email text, guardian_phone text, accepted boolean NOT NULL CHECK(accepted),
 signed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(season_id,player_id,document_version),
 CHECK((signer_capacity='self' AND guardian_email IS NULL AND guardian_phone IS NULL) OR (signer_capacity='parent_or_guardian' AND guardian_email IS NOT NULL AND guardian_phone IS NOT NULL))
);
CREATE INDEX season_player_agreements_user ON public.season_player_agreements(user_id);
CREATE INDEX season_player_agreements_player ON public.season_player_agreements(player_id);
ALTER TABLE public.season_player_agreements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.season_player_agreements FROM anon,authenticated;
GRANT SELECT ON public.season_player_agreements TO authenticated;
CREATE POLICY owner_or_staff_reads_commitment ON public.season_player_agreements FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()) OR EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE FUNCTION inventory_internal.sign_season_player_agreement(p_season_id uuid,p_player_id uuid,p_version text,p_dob date,p_signer text,p_capacity text,p_guardian_email text,p_guardian_phone text,p_accepted boolean) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players%rowtype; s public.seasons%rowtype; d public.season_agreement_documents%rowtype; known_dob date; signature_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in to sign the player agreement.'; END IF;
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND user_id=auth.uid() AND deleted_at IS NULL AND player_category='Member' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Your club member profile was not found.'; END IF;
 SELECT * INTO s FROM public.seasons WHERE id=p_season_id AND is_current FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'This is not the current season.'; END IF;
 IF p_version IS DISTINCT FROM 'DTHC-PLAYER-COMMITMENT-v1' THEN RAISE EXCEPTION 'Refresh to read the current player agreement.'; END IF;
 SELECT * INTO d FROM public.season_agreement_documents WHERE version=p_version;
 IF NOT FOUND THEN RAISE EXCEPTION 'Agreement document unavailable.'; END IF;
 IF p_accepted IS DISTINCT FROM true OR nullif(trim(p_signer),'') IS NULL OR length(trim(p_signer))<3 OR length(p_signer)>300 OR p_dob IS NULL OR p_dob>current_date THEN RAISE EXCEPTION 'Read and acknowledge the agreement, enter a valid birth date, and sign your full legal name.'; END IF;
 SELECT date_of_birth INTO known_dob FROM public.season_packets WHERE player_id=p.id ORDER BY signed_at DESC,id DESC LIMIT 1;
 IF known_dob IS NULL THEN SELECT date_of_birth INTO known_dob FROM public.player_profiles WHERE player_id=p.id; END IF;
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
END $$;
REVOKE ALL ON FUNCTION inventory_internal.sign_season_player_agreement(uuid,uuid,text,date,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory_internal.sign_season_player_agreement(uuid,uuid,text,date,text,text,text,text,boolean) TO authenticated;
CREATE FUNCTION public.sign_season_player_agreement(p_season_id uuid,p_player_id uuid,p_version text,p_dob date,p_signer text,p_capacity text,p_guardian_email text,p_guardian_phone text,p_accepted boolean) RETURNS uuid LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.sign_season_player_agreement(p_season_id,p_player_id,p_version,p_dob,p_signer,p_capacity,p_guardian_email,p_guardian_phone,p_accepted); $$;
REVOKE ALL ON FUNCTION public.sign_season_player_agreement(uuid,uuid,text,date,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sign_season_player_agreement(uuid,uuid,text,date,text,text,text,text,boolean) TO authenticated;

-- Existing active players remain active; this check applies to new activations.
create or replace function public.guard_season_activation() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status='Active' and (tg_op='INSERT' or old.status is distinct from 'Active' or old.approved_packet_id is distinct from new.approved_packet_id) then
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
end $$;
