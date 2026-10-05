CREATE SCHEMA IF NOT EXISTS inventory_internal;
REVOKE ALL ON SCHEMA inventory_internal FROM PUBLIC;
GRANT USAGE ON SCHEMA inventory_internal TO authenticated;
ALTER TABLE public.players DROP CONSTRAINT players_player_category_check;
ALTER TABLE public.players ADD CONSTRAINT players_player_category_check CHECK(player_category IN ('Member','Guest','Inventory'));
CREATE TABLE public.jersey_inventory (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), team text NOT NULL CHECK(team IN ('Men','Women')),
 jersey_number integer NOT NULL CHECK(jersey_number BETWEEN 1 AND 99),
 status text NOT NULL DEFAULT 'Reserved' CHECK(status IN ('Available','Reserved','Assigned','Retired')),
 shirt_size text CHECK(shirt_size IN ('XS','S','M','L','XL','2XL','3XL','4XL','5XL')),
 quantity integer NOT NULL DEFAULT 1 CHECK(quantity BETWEEN 1 AND 999), notes text NOT NULL DEFAULT '',
 player_id uuid REFERENCES public.players(id) ON DELETE SET NULL,
 source_player_id uuid UNIQUE REFERENCES public.players(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(team,jersey_number), CHECK((status='Assigned')=(player_id IS NOT NULL))
);
ALTER TABLE public.jersey_inventory ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.jersey_inventory TO authenticated;
CREATE POLICY inventory_admin_read ON public.jersey_inventory FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE FUNCTION inventory_internal.require_admin() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('admin','manager')) THEN RAISE EXCEPTION 'Admin or manager access required'; END IF; END $$;
CREATE FUNCTION inventory_internal.serialize() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN PERFORM pg_advisory_xact_lock(72614309); RETURN NULL; END $$;
CREATE TRIGGER inventory_serialize BEFORE INSERT OR UPDATE OR DELETE ON public.jersey_inventory FOR EACH STATEMENT EXECUTE FUNCTION inventory_internal.serialize();
CREATE TRIGGER player_inventory_serialize BEFORE INSERT OR UPDATE OR DELETE ON public.players FOR EACH STATEMENT EXECUTE FUNCTION inventory_internal.serialize();
CREATE FUNCTION inventory_internal.guard_player() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.player_category='Inventory' THEN RAISE EXCEPTION 'This record was converted to jersey inventory'; END IF;
 IF NEW.player_category='Inventory' AND (NEW.user_id IS NOT NULL OR NEW.jersey_number IS NOT NULL OR NEW.deleted_at IS NULL OR NEW.purge_after IS NOT NULL) THEN RAISE EXCEPTION 'Invalid archived inventory record'; END IF;
 IF NEW.jersey_number IS NOT NULL AND EXISTS(SELECT 1 FROM public.jersey_inventory i WHERE i.team=NEW.team AND i.jersey_number=NEW.jersey_number AND (i.status IN ('Reserved','Retired') OR (i.status='Assigned' AND i.player_id IS DISTINCT FROM NEW.id))) THEN RAISE EXCEPTION 'Jersey number is reserved in club inventory. Use Assign to player in Jersey Inventory.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER inventory_guard_player BEFORE INSERT OR UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION inventory_internal.guard_player();
CREATE FUNCTION inventory_internal.sync_assignment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  UPDATE public.jersey_inventory SET status='Reserved',player_id=NULL,updated_at=now() WHERE player_id=OLD.id AND status='Assigned';
 ELSE
  UPDATE public.jersey_inventory SET status='Reserved',player_id=NULL,updated_at=now() WHERE player_id=OLD.id AND status='Assigned' AND (NEW.jersey_number IS DISTINCT FROM jersey_number OR NEW.team IS DISTINCT FROM team OR NEW.deleted_at IS NOT NULL);
  IF NEW.deleted_at IS NULL AND NEW.jersey_number IS NOT NULL THEN
   UPDATE public.jersey_inventory SET status='Assigned',player_id=NEW.id,updated_at=now() WHERE team=NEW.team AND jersey_number=NEW.jersey_number AND status='Available';
  END IF;
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER inventory_sync_assignment AFTER UPDATE OR DELETE ON public.players FOR EACH ROW EXECUTE FUNCTION inventory_internal.sync_assignment();
CREATE FUNCTION inventory_internal.convert(p_player_id uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.players%rowtype; v_id uuid;
BEGIN
 PERFORM inventory_internal.require_admin(); PERFORM pg_advisory_xact_lock(72614309);
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR p.user_id IS NOT NULL OR p.jersey_number IS NULL OR p.player_category<>'Member' THEN RAISE EXCEPTION 'Only an unlinked placeholder with a club jersey number can be converted'; END IF;
 IF EXISTS(SELECT 1 FROM public.tournament_players WHERE player_id=p.id) OR EXISTS(SELECT 1 FROM public.season_packets WHERE player_id=p.id) OR EXISTS(SELECT 1 FROM public.attendance_records WHERE player_id=p.id) OR EXISTS(SELECT 1 FROM public.membership_payments WHERE player_id=p.id) THEN RAISE EXCEPTION 'This record has player activity. Review it before converting'; END IF;
 UPDATE public.players SET jersey_number=NULL,player_category='Inventory',deleted_at=now(),purge_after=NULL,status='Inactive',tournament_roster=false WHERE id=p.id;
 UPDATE public.jersey_history SET assignment_status='Released',released_at=now(),released_by=auth.uid(),updated_at=now() WHERE player_id=p.id AND assignment_status<>'Released';
 INSERT INTO public.jersey_inventory(team,jersey_number,shirt_size,source_player_id,notes) VALUES(p.team,p.jersey_number,CASE WHEN p.name ILIKE '%Small%' THEN 'S' WHEN p.name ILIKE '%Blank M' THEN 'M' WHEN p.name ILIKE '%Blank L' THEN 'L' ELSE p.shirt_size END,p.id,'Converted from '||p.name) RETURNING id INTO v_id;
 UPDATE public.season_registrations SET status='Inactive' WHERE player_id=p.id;
 RETURN v_id;
END $$;
CREATE FUNCTION public.admin_convert_uniform(p_player_id uuid) RETURNS uuid LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.convert(p_player_id); $$;
CREATE FUNCTION inventory_internal.save(p_id uuid,p_team text,p_number integer,p_status text,p_size text,p_quantity integer,p_notes text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid; v_old public.jersey_inventory%rowtype;
BEGIN
 PERFORM inventory_internal.require_admin(); PERFORM pg_advisory_xact_lock(72614309);
 IF p_status IS NULL OR p_status NOT IN ('Available','Reserved','Retired') THEN RAISE EXCEPTION 'Choose available, reserved or retired'; END IF;
 IF p_id IS NOT NULL THEN SELECT * INTO v_old FROM public.jersey_inventory WHERE id=p_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Inventory item not found'; END IF; IF v_old.status='Assigned' THEN RAISE EXCEPTION 'Unassign this uniform before editing'; END IF; END IF;
 IF EXISTS(SELECT 1 FROM public.players WHERE team=p_team AND jersey_number=p_number AND deleted_at IS NULL) OR EXISTS(SELECT 1 FROM public.jersey_history WHERE team=p_team AND jersey_number=p_number AND assignment_status<>'Released') THEN RAISE EXCEPTION 'This number is already held by a player or jersey history'; END IF;
 IF p_id IS NULL THEN INSERT INTO public.jersey_inventory(team,jersey_number,status,shirt_size,quantity,notes) VALUES(p_team,p_number,p_status,p_size,p_quantity,coalesce(p_notes,'')) RETURNING id INTO v_id;
 ELSE UPDATE public.jersey_inventory SET team=p_team,jersey_number=p_number,status=p_status,shirt_size=p_size,quantity=p_quantity,notes=coalesce(p_notes,''),updated_at=now() WHERE id=p_id RETURNING id INTO v_id; END IF;
 RETURN v_id;
END $$;
CREATE FUNCTION public.admin_save_uniform(p_id uuid,p_team text,p_number integer,p_status text,p_size text,p_quantity integer,p_notes text) RETURNS uuid LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.save(p_id,p_team,p_number,p_status,p_size,p_quantity,p_notes); $$;
CREATE FUNCTION inventory_internal.assign(p_id uuid,p_player_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE i public.jersey_inventory%rowtype; p public.players%rowtype;
BEGIN
 PERFORM inventory_internal.require_admin(); PERFORM pg_advisory_xact_lock(72614309);
 SELECT * INTO i FROM public.jersey_inventory WHERE id=p_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Uniform not found'; END IF;
 IF p_player_id IS NULL THEN
  IF i.status<>'Assigned' THEN RAISE EXCEPTION 'Uniform is not assigned'; END IF;
  UPDATE public.players SET jersey_number=NULL WHERE id=i.player_id AND team=i.team AND jersey_number=i.jersey_number;
  UPDATE public.jersey_history SET assignment_status='Released',released_at=now(),released_by=auth.uid() WHERE team=i.team AND jersey_number=i.jersey_number AND assignment_status<>'Released';
  UPDATE public.jersey_inventory SET status='Reserved',player_id=NULL,updated_at=now() WHERE id=i.id;
  RETURN;
 END IF;
 IF i.status NOT IN ('Available','Reserved') THEN RAISE EXCEPTION 'Uniform cannot be assigned in its current status'; END IF;
 SELECT * INTO p FROM public.players WHERE id=p_player_id AND deleted_at IS NULL AND player_category='Member' AND team=i.team FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Choose a club member on the same team'; END IF;
 IF EXISTS(SELECT 1 FROM public.players WHERE team=i.team AND jersey_number=i.jersey_number AND id<>p.id) OR EXISTS(SELECT 1 FROM public.jersey_history WHERE team=i.team AND jersey_number=i.jersey_number AND assignment_status<>'Released' AND player_id IS DISTINCT FROM p.id) THEN RAISE EXCEPTION 'Number is already held'; END IF;
 UPDATE public.jersey_inventory SET status='Assigned',player_id=p.id,updated_at=now() WHERE id=i.id;
 UPDATE public.players SET jersey_number=i.jersey_number,shirt_size=coalesce(i.shirt_size,shirt_size) WHERE id=p.id;
END $$;
CREATE FUNCTION public.admin_assign_uniform(p_id uuid,p_player_id uuid) RETURNS void LANGUAGE sql SET search_path='' AS $$ SELECT inventory_internal.assign(p_id,p_player_id); $$;
CREATE OR REPLACE FUNCTION public.get_available_jersey_numbers(p_team text) RETURNS TABLE(jersey_number integer) LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT n FROM generate_series(1,99) n WHERE NOT EXISTS(SELECT 1 FROM public.players WHERE team=p_team AND jersey_number=n AND deleted_at IS NULL) AND NOT EXISTS(SELECT 1 FROM public.jersey_inventory WHERE team=p_team AND jersey_number=n AND status<>'Available') ORDER BY n;
$$;
CREATE OR REPLACE FUNCTION public.is_jersey_number_available(p_team text,p_jersey_number integer,p_player_id uuid DEFAULT NULL) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT NOT EXISTS(SELECT 1 FROM public.jersey_history WHERE team=p_team AND jersey_number=p_jersey_number AND assignment_status<>'Released' AND (p_player_id IS NULL OR player_id IS DISTINCT FROM p_player_id)) AND NOT EXISTS(SELECT 1 FROM public.jersey_inventory WHERE team=p_team AND jersey_number=p_jersey_number AND (status IN ('Reserved','Retired') OR (status='Assigned' AND player_id IS DISTINCT FROM p_player_id)));
$$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA inventory_internal FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory_internal.convert(uuid),inventory_internal.save(uuid,text,integer,text,text,integer,text),inventory_internal.assign(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_convert_uniform(uuid),public.admin_save_uniform(uuid,text,integer,text,text,integer,text),public.admin_assign_uniform(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_convert_uniform(uuid),public.admin_save_uniform(uuid,text,integer,text,text,integer,text),public.admin_assign_uniform(uuid,uuid) TO authenticated;
CREATE FUNCTION inventory_internal.guard_claim() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status='Pending Verification' AND EXISTS(SELECT 1 FROM public.jersey_inventory i JOIN public.players p ON p.id=NEW.player_id AND p.team=i.team WHERE i.jersey_number=NEW.claimed_jersey_number AND i.status IN ('Reserved','Retired')) THEN RAISE EXCEPTION 'This jersey number is reserved in club inventory. Ask an administrator to assign the uniform or choose another number.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER inventory_guard_claim BEFORE INSERT OR UPDATE ON public.jersey_claims FOR EACH ROW EXECUTE FUNCTION inventory_internal.guard_claim();
REVOKE ALL ON FUNCTION inventory_internal.guard_claim() FROM PUBLIC;
