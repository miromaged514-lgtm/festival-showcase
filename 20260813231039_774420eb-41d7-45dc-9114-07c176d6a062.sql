ALTER TABLE public.servant_requests
  ADD COLUMN IF NOT EXISTS certificate_path text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS rejection_reason text NOT NULL DEFAULT '';

ALTER TABLE public.servant_requests ALTER COLUMN status SET DEFAULT 'pending_servant_approval';
UPDATE public.servant_requests SET status = 'pending_servant_approval' WHERE status = 'pending';
UPDATE public.servant_requests SET status = 'rejected_servant_application' WHERE status = 'rejected';

DROP TABLE IF EXISTS public.servant_codes;

DROP POLICY IF EXISTS "Owners read own servant docs" ON storage.objects;
CREATE POLICY "Owners read own servant docs" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'servant-docs' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Admins read servant docs" ON storage.objects;
CREATE POLICY "Admins read servant docs" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'servant-docs' AND private.is_admin(auth.uid()));