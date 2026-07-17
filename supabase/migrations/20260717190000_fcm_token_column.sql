ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS invite_code TEXT;
