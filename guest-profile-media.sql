CREATE OR REPLACE FUNCTION guest_internal.clean_info(p_info jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb; k text;
BEGIN
 IF p_info IS NULL OR jsonb_typeof(p_info)<>'object' OR octet_length(p_info::text)>200000 THEN RAISE EXCEPTION 'Invalid guest information'; END IF;
 result='{}'::jsonb;
 FOREACH k IN ARRAY ARRAY['name','team','email','phone','home_club','position','shirt_size','emergency_name','emergency_phone','instagram','facebook','tiktok'] LOOP
  IF p_info ? k AND jsonb_typeof(p_info->k)<>'string' THEN RAISE EXCEPTION 'Invalid information field'; END IF;
  IF length(coalesce(p_info->>k,''))>300 THEN RAISE EXCEPTION 'Information field is too long'; END IF;
  result=result||jsonb_build_object(k,trim(coalesce(p_info->>k,'')));
 END LOOP;
 IF length(result->>'name')<2 OR result->>'team' NOT IN ('Men','Women') THEN RAISE EXCEPTION 'Enter a name and select a team'; END IF;
 IF result->>'email'<>'' AND result->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' THEN RAISE EXCEPTION 'Enter a valid email'; END IF;
 IF result->>'position' NOT IN ('','Goalie','Pivot','R. Wing','L. Wing','R. Back','L. Back','Center back') THEN RAISE EXCEPTION 'Choose a playing position'; END IF;
 IF result->>'shirt_size' NOT IN ('','XS','S','M','L','XL','2XL','3XL') THEN RAISE EXCEPTION 'Choose a shirt size'; END IF;
 FOREACH k IN ARRAY ARRAY['instagram','facebook','tiktok'] LOOP
  IF result->>k<>'' AND result->>k !~ '^@?[A-Za-z0-9._-]{1,100}$' THEN RAISE EXCEPTION 'Enter social media usernames, not links'; END IF;
 END LOOP;
 IF p_info ? 'profile_photo' THEN
  IF jsonb_typeof(p_info->'profile_photo')<>'string' THEN RAISE EXCEPTION 'Invalid profile photo'; END IF;
  IF length(p_info->>'profile_photo')>180000 OR ((p_info->>'profile_photo')<>'' AND (p_info->>'profile_photo') !~ '^data:image/jpeg;base64,[A-Za-z0-9+/]+=*$') THEN RAISE EXCEPTION 'Choose a valid, smaller profile photo'; END IF;
  result=result||jsonb_build_object('profile_photo',p_info->>'profile_photo');
 ELSE
  result=result||jsonb_build_object('profile_photo','');
 END IF;
 RETURN result;
END; $$;

