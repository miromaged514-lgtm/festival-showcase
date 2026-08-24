CREATE OR REPLACE VIEW public.public_profiles
WITH (security_invoker = off) AS
SELECT p.id,
       p.display_name,
       c.member_no,
       c.church,
       c.stage
FROM public.profiles p
LEFT JOIN public.profile_contacts c ON c.user_id = p.id;

REVOKE ALL ON public.public_profiles FROM anon;
GRANT SELECT ON public.public_profiles TO authenticated;
GRANT SELECT ON public.public_profiles TO service_role;