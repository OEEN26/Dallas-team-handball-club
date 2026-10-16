-- Physical jerseys are separate from official number reservations.
CREATE TABLE public.jersey_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 team text NOT NULL CHECK(team IN ('Men','Women','Youth')),
 jersey_number integer NOT NULL CHECK(jersey_number BETWEEN 0 AND 999),
 shirt_size text NOT NULL DEFAULT '' CHECK(length(shirt_size)<=30),
 status text NOT NULL DEFAULT 'Available' CHECK(status IN ('Available','Assigned','Borrowed','Reserved','Unavailable')),
 player_id uuid REFERENCES public.players(id) ON DELETE SET NULL,
 holder_name text NOT NULL DEFAULT '' CHECK(length(holder_name)<=300),
 issued_at date, due_at date, notes text NOT NULL DEFAULT '' CHECK(length(notes)<=3000),
 legacy_id uuid REFERENCES public.jersey_inventory(id) ON DELETE SET NULL,
 legacy_piece integer, UNIQUE(legacy_id,legacy_piece),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(status NOT IN ('Assigned','Borrowed') OR length(trim(holder_name))>0),
 CHECK(due_at IS NULL OR (issued_at IS NOT NULL AND due_at>=issued_at))
);
CREATE INDEX jersey_items_team_number ON public.jersey_items(team,jersey_number);
CREATE INDEX jersey_items_player ON public.jersey_items(player_id);
CREATE TABLE public.jersey_item_history (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 item_id uuid NOT NULL REFERENCES public.jersey_items(id) ON DELETE CASCADE,
 changed_at timestamptz NOT NULL DEFAULT now(), changed_by uuid DEFAULT auth.uid(),
 action text NOT NULL, previous jsonb, current_record jsonb NOT NULL
);
CREATE INDEX jersey_item_history_item_time ON public.jersey_item_history(item_id,changed_at DESC);
ALTER TABLE public.jersey_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jersey_item_history ENABLE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,UPDATE ON public.jersey_items TO authenticated;
GRANT SELECT ON public.jersey_item_history TO authenticated;
CREATE POLICY staff_reads_jersey_items ON public.jersey_items FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE POLICY staff_adds_jersey_items ON public.jersey_items FOR INSERT TO authenticated WITH CHECK(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE POLICY staff_updates_jersey_items ON public.jersey_items FOR UPDATE TO authenticated USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager'))) WITH CHECK(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE POLICY staff_reads_jersey_history ON public.jersey_item_history FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role IN ('admin','manager')));
CREATE FUNCTION inventory_internal.stamp_jersey_item() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN NEW.updated_at=clock_timestamp(); RETURN NEW; END $$;
CREATE TRIGGER stamp_jersey_item BEFORE UPDATE ON public.jersey_items FOR EACH ROW EXECUTE FUNCTION inventory_internal.stamp_jersey_item();
CREATE FUNCTION inventory_internal.log_jersey_item() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.jersey_item_history(item_id,action,previous,current_record) VALUES(NEW.id,CASE WHEN TG_OP='INSERT' THEN 'Added' WHEN OLD.status IN ('Borrowed','Assigned') AND NEW.status='Available' THEN 'Returned' WHEN OLD.status IS DISTINCT FROM NEW.status THEN NEW.status ELSE 'Updated' END,CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) ELSE NULL END,to_jsonb(NEW));
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION inventory_internal.stamp_jersey_item(),inventory_internal.log_jersey_item() FROM PUBLIC;
CREATE TRIGGER log_jersey_item AFTER INSERT OR UPDATE ON public.jersey_items FOR EACH ROW EXECUTE FUNCTION inventory_internal.log_jersey_item();
-- Existing blank uniforms are physical stock; number-only reservations stay in the registry.
INSERT INTO public.jersey_items(team,jersey_number,shirt_size,status,holder_name,player_id,notes,legacy_id,legacy_piece)
SELECT i.team,i.jersey_number,coalesce(i.shirt_size,''),CASE WHEN i.status='Retired' THEN 'Unavailable' ELSE i.status END,coalesce(p.name,''),i.player_id,i.notes,i.id,n
FROM public.jersey_inventory i LEFT JOIN public.players p ON p.id=i.player_id CROSS JOIN LATERAL generate_series(1,i.quantity) n
WHERE i.notes ILIKE '%blank%' OR i.status IN ('Available','Assigned') ON CONFLICT(legacy_id,legacy_piece) DO NOTHING;
