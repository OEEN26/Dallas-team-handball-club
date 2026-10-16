ALTER TABLE public.tournaments ADD COLUMN finished_at timestamptz, ADD COLUMN finished_by uuid;
CREATE TABLE public.tournament_participants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
 player_id uuid REFERENCES public.players(id) ON DELETE SET NULL,
 player_name text NOT NULL, team text, player_category text, jersey_number integer CHECK(jersey_number BETWEEN 1 AND 99),
 recorded_at timestamptz NOT NULL DEFAULT now(), recorded_by uuid
);
CREATE INDEX tournament_participants_tournament ON public.tournament_participants(tournament_id);
CREATE INDEX tournament_participants_player ON public.tournament_participants(player_id);
CREATE UNIQUE INDEX tournament_participants_unique_player ON public.tournament_participants(tournament_id,player_id) WHERE player_id IS NOT NULL;
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.tournament_participants TO authenticated;
CREATE POLICY staff_reads_final_roster ON public.tournament_participants FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE FUNCTION inventory_internal.finish_tournament(p_tournament_id uuid,p_participants jsonb,p_expected_updated_at timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
REVOKE ALL ON FUNCTION inventory_internal.finish_tournament(uuid,jsonb,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory_internal.finish_tournament(uuid,jsonb,timestamptz) TO authenticated;
CREATE FUNCTION public.admin_finish_tournament(p_tournament_id uuid,p_participants jsonb,p_expected_updated_at timestamptz) RETURNS void LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.finish_tournament(p_tournament_id,p_participants,p_expected_updated_at); $$;
REVOKE ALL ON FUNCTION public.admin_finish_tournament(uuid,jsonb,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_finish_tournament(uuid,jsonb,timestamptz) TO authenticated;
