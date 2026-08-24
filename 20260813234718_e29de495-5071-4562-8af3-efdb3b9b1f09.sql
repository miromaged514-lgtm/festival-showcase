-- 1. Policies on works/comments call private.is_my_served, but authenticated
--    had no EXECUTE privilege, so every query errored out (empty gallery).
GRANT EXECUTE ON FUNCTION private.is_my_served(uuid, uuid) TO authenticated;

-- 2. Server-authoritative ownership + status on insert.
CREATE OR REPLACE FUNCTION public.works_set_author_and_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.owner_id := auth.uid();

  IF private.is_admin(auth.uid()) OR private.has_role(auth.uid(), 'servant'::public.app_role) THEN
    NEW.status := 'approved'::public.work_status;
    NEW.reviewed_by := auth.uid();
    NEW.reviewed_at := now();
    NEW.rejection_reason := '';
  ELSE
    NEW.status := 'pending'::public.work_status;
    NEW.reviewed_by := NULL;
    NEW.reviewed_at := NULL;
    NEW.rejection_reason := '';
  END IF;

  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS works_set_author_and_status ON public.works;
CREATE TRIGGER works_set_author_and_status
BEFORE INSERT ON public.works
FOR EACH ROW EXECUTE FUNCTION public.works_set_author_and_status();

-- 3. Record moderation metadata automatically on status change.
CREATE OR REPLACE FUNCTION public.works_record_moderation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.reviewed_by := auth.uid();
    NEW.reviewed_at := now();
    IF NEW.status <> 'rejected'::public.work_status THEN
      NEW.rejection_reason := '';
    END IF;
  END IF;
  -- owner can never be reassigned
  NEW.owner_id := OLD.owner_id;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS works_record_moderation ON public.works;
CREATE TRIGGER works_record_moderation
BEFORE UPDATE ON public.works
FOR EACH ROW EXECUTE FUNCTION public.works_record_moderation();