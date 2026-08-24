-- 1) Moderation metadata on works
ALTER TABLE public.works
  ADD COLUMN IF NOT EXISTS reviewed_by uuid,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason text NOT NULL DEFAULT '';

-- 2) Servant code lifecycle
ALTER TABLE public.servant_codes
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS sent_to text NOT NULL DEFAULT '';
CREATE UNIQUE INDEX IF NOT EXISTS servant_codes_code_uidx ON public.servant_codes (code);

-- 3) Scope helper: is _owner one of _servant's assigned served members?
CREATE OR REPLACE FUNCTION private.is_my_served(_servant uuid, _owner uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profile_contacts c
    WHERE c.user_id = _owner AND c.assigned_servant = _servant
  );
$$;

REVOKE ALL ON FUNCTION private.is_my_served(uuid, uuid) FROM PUBLIC;

-- 4) Works: replace blanket servant policies with scoped ones
DROP POLICY IF EXISTS "Servants see all works" ON public.works;
DROP POLICY IF EXISTS "Servants update any work" ON public.works;
DROP POLICY IF EXISTS "Servants delete any work" ON public.works;

CREATE POLICY "Servants see scoped works" ON public.works
FOR SELECT TO authenticated
USING (private.has_role(auth.uid(), 'servant'::app_role) AND private.is_my_served(auth.uid(), owner_id));

CREATE POLICY "Servants update scoped works" ON public.works
FOR UPDATE TO authenticated
USING (private.has_role(auth.uid(), 'servant'::app_role) AND private.is_my_served(auth.uid(), owner_id))
WITH CHECK (private.has_role(auth.uid(), 'servant'::app_role) AND private.is_my_served(auth.uid(), owner_id));

CREATE POLICY "Servants delete scoped works" ON public.works
FOR DELETE TO authenticated
USING (private.has_role(auth.uid(), 'servant'::app_role) AND private.is_my_served(auth.uid(), owner_id));

-- 5) Comments: servants moderate only within their scope
DROP POLICY IF EXISTS "Servants delete any comment" ON public.comments;

CREATE POLICY "Servants delete scoped comments" ON public.comments
FOR DELETE TO authenticated
USING (
  private.has_role(auth.uid(), 'servant'::app_role)
  AND (
    private.is_my_served(auth.uid(), user_id)
    OR EXISTS (SELECT 1 FROM public.works w WHERE w.id = comments.work_id AND w.owner_id = auth.uid())
  )
);

-- 6) Reactions: only owner or admin may delete
DROP POLICY IF EXISTS "Servants delete any reaction" ON public.reactions;
