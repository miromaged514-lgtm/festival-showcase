CREATE OR REPLACE FUNCTION private.is_admin(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'admin'::public.app_role) $$;

CREATE OR REPLACE FUNCTION private.is_staff(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('admin'::public.app_role, 'servant'::public.app_role)) $$;

-- servant codes: admin only
CREATE POLICY "Admins manage servant codes" ON public.servant_codes FOR ALL TO authenticated
  USING (private.is_admin(auth.uid())) WITH CHECK (private.is_admin(auth.uid()));

-- servant requests: admin manage
CREATE POLICY "Admins manage servant requests" ON public.servant_requests FOR ALL TO authenticated
  USING (private.is_admin(auth.uid())) WITH CHECK (private.is_admin(auth.uid()));

-- contacts visible to staff
CREATE POLICY "Staff view contacts" ON public.profile_contacts FOR SELECT TO authenticated
  USING (private.is_staff(auth.uid()));

-- user roles administration
CREATE POLICY "Admins view all roles" ON public.user_roles FOR SELECT TO authenticated USING (private.is_admin(auth.uid()));
CREATE POLICY "Admins insert roles" ON public.user_roles FOR INSERT TO authenticated WITH CHECK (private.is_admin(auth.uid()));
CREATE POLICY "Admins update roles" ON public.user_roles FOR UPDATE TO authenticated USING (private.is_admin(auth.uid())) WITH CHECK (private.is_admin(auth.uid()));
CREATE POLICY "Admins delete roles" ON public.user_roles FOR DELETE TO authenticated USING (private.is_admin(auth.uid()));

-- admin oversight over content
CREATE POLICY "Admins see all works" ON public.works FOR SELECT TO authenticated USING (private.is_admin(auth.uid()));
CREATE POLICY "Admins update any work" ON public.works FOR UPDATE TO authenticated USING (private.is_admin(auth.uid())) WITH CHECK (private.is_admin(auth.uid()));
CREATE POLICY "Admins delete any work" ON public.works FOR DELETE TO authenticated USING (private.is_admin(auth.uid()));
CREATE POLICY "Admins delete any comment" ON public.comments FOR DELETE TO authenticated USING (private.is_admin(auth.uid()));
CREATE POLICY "Admins delete any reaction" ON public.reactions FOR DELETE TO authenticated USING (private.is_admin(auth.uid()));

-- signup handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $function$
DECLARE
  _requested public.app_role;
  _role public.app_role;
  _code text;
  _code_id uuid;
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)));

  INSERT INTO public.profile_contacts (user_id, phone, church)
  VALUES (NEW.id,
          COALESCE(NEW.raw_user_meta_data->>'phone', ''),
          COALESCE(NEW.raw_user_meta_data->>'church', ''))
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