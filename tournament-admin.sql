ALTER TABLE public.tournaments ADD COLUMN placement text CHECK(length(placement)<=200);
CREATE FUNCTION inventory_internal.update_tournament_roster(p_id uuid,p_expected_updated_at timestamptz,p_values jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.tournament_players%rowtype; tid uuid; t public.tournaments%rowtype; p public.players%rowtype; next_status text; next_number integer;
BEGIN
 PERFORM inventory_internal.require_admin();
 SELECT tournament_id INTO tid FROM public.tournament_players WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Roster entry not found'; END IF;
 SELECT * INTO t FROM public.tournaments WHERE id=tid FOR UPDATE;
 IF t.status='Completed' THEN RAISE EXCEPTION 'Use the final roster to correct a completed tournament.'; END IF;
 SELECT * INTO r FROM public.tournament_players WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR r.updated_at IS DISTINCT FROM p_expected_updated_at THEN RAISE EXCEPTION 'This roster entry changed. Refresh before saving.'; END IF;
 SELECT * INTO p FROM public.players WHERE id=r.player_id AND deleted_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Player unavailable'; END IF;
 next_status=coalesce(p_values->>'roster_status',r.roster_status);
 IF next_status NOT IN ('Interested','Selected','Confirmed','Alternate','Not Going') THEN RAISE EXCEPTION 'Choose a valid roster status'; END IF;
 next_number=CASE WHEN p_values ? 'jersey_number' THEN nullif(p_values->>'jersey_number','')::integer ELSE r.jersey_number END;
 IF next_number IS NOT NULL AND next_number NOT BETWEEN 1 AND 99 THEN RAISE EXCEPTION 'Jersey number must be between 1 and 99'; END IF;
 IF next_status IN ('Selected','Confirmed') THEN
  IF p.player_category='Member' AND NOT EXISTS(SELECT 1 FROM public.season_registrations sr JOIN public.seasons s ON s.id=sr.season_id WHERE s.is_current AND sr.player_id=p.id AND sr.status='Active') THEN RAISE EXCEPTION 'Approve this member for the current season first'; END IF;
  IF next_number IS NOT NULL AND EXISTS(SELECT 1 FROM public.tournament_players tp JOIN public.players other ON other.id=tp.player_id WHERE tp.tournament_id=tid AND tp.id<>r.id AND tp.roster_status IN ('Selected','Confirmed') AND coalesce(tp.jersey_number,other.jersey_number)=next_number) THEN RAISE EXCEPTION 'That tournament jersey number is already assigned'; END IF;
 END IF;
 UPDATE public.tournament_players SET roster_status=next_status,jersey_number=next_number,
 travel_status=coalesce(p_values->>'travel_status',r.travel_status),hotel_status=coalesce(p_values->>'hotel_status',r.hotel_status),
 waiver_status=coalesce(p_values->>'waiver_status',r.waiver_status),fee_status=coalesce(p_values->>'fee_status',r.fee_status),
 notes=CASE WHEN p_values ? 'notes' THEN p_values->>'notes' ELSE r.notes END,updated_at=clock_timestamp() WHERE id=r.id;
END $$;
REVOKE ALL ON FUNCTION inventory_internal.update_tournament_roster(uuid,timestamptz,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory_internal.update_tournament_roster(uuid,timestamptz,jsonb) TO authenticated;
CREATE FUNCTION public.admin_update_tournament_roster(p_id uuid,p_expected_updated_at timestamptz,p_values jsonb) RETURNS void LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.update_tournament_roster(p_id,p_expected_updated_at,p_values); $$;
REVOKE ALL ON FUNCTION public.admin_update_tournament_roster(uuid,timestamptz,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_tournament_roster(uuid,timestamptz,jsonb) TO authenticated;
