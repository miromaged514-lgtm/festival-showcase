CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _role public.app_role;
  _stage public.service_stage;
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)));

  BEGIN
    _stage := NULLIF(NEW.raw_user_meta_data->>'stage','')::public.service_stage;
  EXCEPTION WHEN others THEN _stage := NULL; END;

  INSERT INTO public.profile_contacts (user_id, phone, church, stage, course)
  VALUES (NEW.id,
          COALESCE(NEW.raw_user_meta_data->>'phone', ''),
          COALESCE(NEW.raw_user_meta_data->>'church', ''),
          _stage,
          COALESCE(NEW.raw_user_meta_data->>'course', ''))
  ON CONFLICT (user_id) DO NOTHING;

  -- Role is never chosen by the signing-up user; admins promote later.
  _role := 'served';
  IF lower(NEW.email) = 'miromaged514@gmail.com' THEN
    _role := 'admin';
  END IF;

  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, _role)
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END; $function$;