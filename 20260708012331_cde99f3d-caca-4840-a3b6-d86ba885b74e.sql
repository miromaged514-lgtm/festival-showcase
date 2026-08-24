
-- 1) Restrict SELECT on profiles/comments/reactions to authenticated users
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles viewable by authenticated" ON public.profiles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Comments are public" ON public.comments;
CREATE POLICY "Comments viewable by authenticated" ON public.comments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Reactions are public" ON public.reactions;
CREATE POLICY "Reactions viewable by authenticated" ON public.reactions
  FOR SELECT TO authenticated USING (true);

-- Revoke anon SELECT grants (were only needed for public policies)
REVOKE SELECT ON public.profiles FROM anon;
REVOKE SELECT ON public.comments FROM anon;
REVOKE SELECT ON public.reactions FROM anon;

-- 2) Restrict storage bucket 'works' reads to authenticated users
DROP POLICY IF EXISTS "Public can read work files" ON storage.objects;
CREATE POLICY "Authenticated can read work files" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'works');

-- 3) Move has_role out of the public API schema
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
$$;

REVOKE ALL ON FUNCTION private.has_role(uuid, public.app_role) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.has_role(uuid, public.app_role) TO authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

-- Rewrite policies to use private.has_role
DROP POLICY IF EXISTS "Servants see all works" ON public.works;
CREATE POLICY "Servants see all works" ON public.works
  FOR SELECT TO authenticated USING (private.has_role(auth.uid(), 'servant'::public.app_role));

DROP POLICY IF EXISTS "Servants update any work" ON public.works;
CREATE POLICY "Servants update any work" ON public.works
  FOR UPDATE TO authenticated USING (private.has_role(auth.uid(), 'servant'::public.app_role));

DROP POLICY IF EXISTS "Servants delete any work" ON public.works;
CREATE POLICY "Servants delete any work" ON public.works
  FOR DELETE TO authenticated USING (private.has_role(auth.uid(), 'servant'::public.app_role));

DROP POLICY IF EXISTS "Servants delete any reaction" ON public.reactions;
CREATE POLICY "Servants delete any reaction" ON public.reactions
  FOR DELETE TO authenticated USING (private.has_role(auth.uid(), 'servant'::public.app_role));

DROP POLICY IF EXISTS "Servants delete any comment" ON public.comments;
CREATE POLICY "Servants delete any comment" ON public.comments
  FOR DELETE TO authenticated USING (private.has_role(auth.uid(), 'servant'::public.app_role));

-- Drop the public-schema function (now unused by policies)
DROP FUNCTION IF EXISTS public.has_role(uuid, public.app_role);
