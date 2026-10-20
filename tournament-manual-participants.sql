CREATE OR REPLACE FUNCTION inventory_internal.finish_tournament(p_tournament_id uuid,p_participants jsonb,p_expected_updated_at timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.tournaments%rowtype; entry jsonb; p public.players%rowtype; prior public.tournament_participants%rowtype; staged jsonb='[]'::jsonb; seen text[]='{}'; identity_key text; number_value integer;
BEGIN
 PERFORM inventory_internal.require_admin();
 SELECT * INTO t FROM public.tournaments WHERE id=p_tournament_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Tournament not found'; END IF;
 IF t.updated_at IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'Tournament changed. Refresh before saving the final roster.'; END IF;
 IF jsonb_typeof(p_participants) IS DISTINCT FROM 'array' OR jsonb_array_length(p_participants)=0 THEN RAISE EXCEPTION 'Select at least one participant'; END IF;
 IF jsonb_array_length(p_participants)>300 THEN RAISE EXCEPTION 'Too many participants'; END IF;
 FOR entry IN SELECT value FROM jsonb_array_elements(p_participants) LOOP
  prior=NULL; p=NULL;
  IF nullif(entry->>'snapshot_id','') IS NOT NULL THEN
   SELECT * INTO prior FROM public.tournament_participants WHERE id=(entry->>'snapshot_id')::uuid AND tournament_id=t.id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Final roster entry not found. Refresh first.'; END IF;
   IF prior.player_id IS NULL AND nullif(entry->>'player_id','') IS NOT NULL THEN
    SELECT * INTO p FROM public.players WHERE id=(entry->>'player_id')::uuid AND deleted_at IS NULL AND player_category IN ('Member','Guest');
    IF NOT FOUND THEN RAISE EXCEPTION 'The profile to link is no longer available'; END IF;
   END IF;
  ELSIF nullif(entry->>'player_id','') IS NULL THEN
   IF length(btrim(coalesce(entry->>'player_name',''))) NOT BETWEEN 3 AND 150 OR btrim(entry->>'player_name') !~ '[[:space:]]' THEN RAISE EXCEPTION 'Enter a first and last name (maximum 150 characters)'; END IF;
   IF coalesce(entry->>'team','') NOT IN ('Men','Women','Youth') OR coalesce(entry->>'player_category','') NOT IN ('Member','Guest') THEN RAISE EXCEPTION 'Choose a team and player group'; END IF;
   prior.id=gen_random_uuid(); prior.player_name=btrim(entry->>'player_name'); prior.team=entry->>'team'; prior.player_category=entry->>'player_category';
  ELSE
   SELECT * INTO p FROM public.players WHERE id=(entry->>'player_id')::uuid AND deleted_at IS NULL AND player_category IN ('Member','Guest');
   IF NOT FOUND THEN RAISE EXCEPTION 'One selected player is no longer available. Refresh first.'; END IF;
  END IF;
  identity_key=coalesce(prior.player_id::text,p.id::text,prior.id::text);
  IF identity_key=ANY(seen) THEN RAISE EXCEPTION 'A participant was selected twice'; END IF;
  seen=array_append(seen,identity_key);
  number_value=nullif(entry->>'jersey_number','')::integer;
  IF number_value IS NOT NULL AND (number_value<1 OR number_value>99) THEN RAISE EXCEPTION 'Jersey numbers must be between 1 and 99'; END IF;
  staged=staged||jsonb_build_array(jsonb_build_object('id',coalesce(prior.id,gen_random_uuid()),'player_id',coalesce(prior.player_id,p.id),'player_name',coalesce(prior.player_name,p.name),'team',coalesce(prior.team,p.team),'player_category',coalesce(prior.player_category,p.player_category),'jersey_number',number_value));
 END LOOP;
 DELETE FROM public.tournament_participants WHERE tournament_id=t.id;
 INSERT INTO public.tournament_participants(id,tournament_id,player_id,player_name,team,player_category,jersey_number,recorded_by)
 SELECT x.id,t.id,x.player_id,x.player_name,x.team,x.player_category,x.jersey_number,auth.uid() FROM jsonb_to_recordset(staged) AS x(id uuid,player_id uuid,player_name text,team text,player_category text,jersey_number integer);
 UPDATE public.tournaments SET status='Completed',finished_at=coalesce(finished_at,now()),finished_by=auth.uid(),updated_at=clock_timestamp() WHERE id=t.id;
END $$;
