ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'admin';

CREATE TABLE public.profile_contacts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text NOT NULL DEFAULT '',
  church text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profile_contacts TO authenticated;
GRANT ALL ON public.profile_contacts TO service_role;
ALTER TABLE public.profile_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own contact" ON public.profile_contacts FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users insert own contact" ON public.profile_contacts FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own contact" ON public.profile_contacts FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER profile_contacts_set_updated_at BEFORE UPDATE ON public.profile_contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.servant_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  used_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.servant_codes TO authenticated;
GRANT ALL ON public.servant_codes TO service_role;
ALTER TABLE public.servant_codes ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.servant_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.servant_requests TO authenticated;
GRANT ALL ON public.servant_requests TO service_role;
ALTER TABLE public.servant_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own servant request" ON public.servant_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);