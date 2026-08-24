-- 1) service stage enum
DO $$ BEGIN
  CREATE TYPE public.service_stage AS ENUM ('primary','preparatory','secondary','university','graduates');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) extend profile_contacts
CREATE SEQUENCE IF NOT EXISTS public.member_no_seq START 1000;

ALTER TABLE public.profile_contacts
  ADD COLUMN IF NOT EXISTS stage public.service_stage,
  ADD COLUMN IF NOT EXISTS course text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS assigned_servant uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS member_no bigint;

ALTER TABLE public.profile_contacts
  ALTER COLUMN member_no SET DEFAULT nextval('public.member_no_seq');

UPDATE public.profile_contacts SET member_no = nextval('public.member_no_seq') WHERE member_no IS NULL;

ALTER TABLE public.profile_contacts ALTER COLUMN member_no SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.profile_contacts ADD CONSTRAINT profile_contacts_member_no_key UNIQUE (member_no);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS profile_contacts_assigned_servant_idx ON public.profile_contacts(assigned_servant);

-- 3) policies
DROP POLICY IF EXISTS "Admins manage contacts" ON public.profile_contacts;
CREATE POLICY "Admins manage contacts" ON public.profile_contacts
  FOR ALL TO authenticated
  USING (private.is_admin(auth.uid()))
  WITH CHECK (private.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Servants update assigned contacts" ON public.profile_contacts;
CREATE POLICY "Servants update assigned contacts" ON public.profile_contacts
  FOR UPDATE TO authenticated
  USING (private.has_role(auth.uid(), 'servant'::public.app_role) AND assigned_servant = auth.uid())
  WITH CHECK (private.has_role(auth.uid(), 'servant'::public.app_role) AND assigned_servant = auth.uid());

DROP POLICY IF EXISTS "Admins update any profile" ON public.profiles;
CREATE POLICY "Admins update any profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (private.is_admin(auth.uid()))
  WITH CHECK (private.is_admin(auth.uid()));

-- 4) signup metadata -> stage / course
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _requested public.app_role;
  _role public.app_role;
  _code text;
  _code_id uuid;
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

  _requested := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role','')::public.app_role, 'served');
  IF _requested = 'admin' THEN _requested := 'served'; END IF;
  _code := upper(trim(COALESCE(NEW.raw_user_meta_data->>'servant_code','')));
  _role := 'served';

  IF lower(NEW.email) = 'miromaged514@gmail.com' THEN
    _role := 'admin';
  ELSIF _requested = 'servant' THEN
    IF _code <> '' THEN
      SELECT id INTO _code_id FROM public.servant_codes
      WHERE upper(code) = _code AND used_by IS NULL LIMIT 1;
      IF _code_id IS NOT NULL THEN
        UPDATE public.servant_codes SET used_by = NEW.id, used_at = now() WHERE id = _code_id;
        _role := 'servant';
      END IF;
    END IF;
    IF _role <> 'servant' THEN
      INSERT INTO public.servant_requests (user_id) VALUES (NEW.id)
      ON CONFLICT (user_id) DO NOTHING;
    END IF;
  END IF;

  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, _role)
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END; $function$;