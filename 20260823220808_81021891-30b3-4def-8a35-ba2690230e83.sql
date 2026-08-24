-- Servants must see all works to moderate the pending queue
DROP POLICY IF EXISTS "Servants see scoped works" ON public.works;
CREATE POLICY "Servants see all works" ON public.works
FOR SELECT TO authenticated
USING (private.has_role(auth.uid(), 'servant'::public.app_role));

-- Safe moderation path (no content editing rights for servants)
CREATE OR REPLACE FUNCTION public.moderate_work(
  _id uuid,
  _status public.work_status DEFAULT NULL,
  _rating integer DEFAULT NULL,
  _reason text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (private.is_admin(auth.uid()) OR private.has_role(auth.uid(), 'servant'::public.app_role)) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.works w
  SET status = COALESCE(_status, w.status),
      rating = COALESCE(_rating, w.rating),
      rejection_reason = CASE
        WHEN _status = 'rejected'::public.work_status THEN COALESCE(_reason, '')
        WHEN _status IS NOT NULL THEN ''
        ELSE w.rejection_reason
      END,
      reviewed_by = CASE WHEN _status IS NOT NULL THEN auth.uid() ELSE w.reviewed_by END,
      reviewed_at = CASE WHEN _status IS NOT NULL THEN now() ELSE w.reviewed_at END
  WHERE w.id = _id;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_work(uuid, public.work_status, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_work(uuid, public.work_status, integer, text) TO authenticated;