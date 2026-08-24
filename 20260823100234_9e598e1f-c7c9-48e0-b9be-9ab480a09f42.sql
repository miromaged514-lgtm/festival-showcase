DROP POLICY IF EXISTS "Staff view user roles" ON public.user_roles;
CREATE POLICY "Staff view user roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (private.is_staff(auth.uid()));