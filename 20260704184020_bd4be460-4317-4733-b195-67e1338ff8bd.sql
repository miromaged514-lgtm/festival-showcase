
-- Lock down security definer functions from direct client execution
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_updated_at() FROM anon, authenticated, PUBLIC;

-- Storage policies for the private 'works' bucket
-- Public read (so approved works can be shown to anyone)
CREATE POLICY "Public can read work files"
ON storage.objects FOR SELECT
USING (bucket_id = 'works');

-- Authenticated users can upload into a folder named by their user id
CREATE POLICY "Users upload own work files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'works' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users update own work files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'works' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users delete own work files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'works' AND auth.uid()::text = (storage.foldername(name))[1]);
