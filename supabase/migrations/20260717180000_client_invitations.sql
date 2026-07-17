-- =============================================================
-- Migration: Client Invitation RLS Policies
-- =============================================================

-- Drop existing policies if they already exist
DROP POLICY IF EXISTS "Clients can unlink themselves" ON public.clients;
DROP POLICY IF EXISTS "Clients can link themselves via invite code" ON public.clients;
DROP POLICY IF EXISTS "Clients can select unlinked client record" ON public.clients;

-- 1. Allow a linked client to clear their own connection (unlink)
CREATE POLICY "Clients can unlink themselves"
  ON public.clients
  FOR UPDATE
  USING (auth.uid() = client_user_id)
  WITH CHECK (client_user_id IS NULL);

-- 2. Allow a client to link their own user ID to a client record using the Invite Code
CREATE POLICY "Clients can link themselves via invite code"
  ON public.clients
  FOR UPDATE
  USING (client_user_id IS NULL)
  WITH CHECK (client_user_id = auth.uid());

-- 3. Allow a client to select unlinked client records to read invite code details
CREATE POLICY "Clients can select unlinked client record"
  ON public.clients
  FOR SELECT
  USING (client_user_id IS NULL OR auth.uid() = client_user_id OR auth.uid() = user_id);
