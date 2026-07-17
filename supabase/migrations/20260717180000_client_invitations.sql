-- =============================================================
-- Migration: Client Invitation RLS Policies
-- =============================================================

-- Drop existing policies if they already exist
DROP POLICY IF EXISTS "Clients can unlink themselves" ON public.clients;
DROP POLICY IF EXISTS "Clients can link themselves via invite code" ON public.clients;
DROP POLICY IF EXISTS "Clients can select unlinked client record" ON public.clients;
DROP POLICY IF EXISTS "Clients can manage their own connection" ON public.clients;

-- 1. Allow a client to select client records where they are linked, or unlinked records
CREATE POLICY "Clients can select unlinked client record"
  ON public.clients
  FOR SELECT
  USING (client_user_id IS NULL OR auth.uid() = client_user_id OR auth.uid() = user_id);

-- 2. Allow a client to link/unlink their own user ID to a client record
CREATE POLICY "Clients can manage their own connection"
  ON public.clients
  FOR UPDATE
  USING (client_user_id IS NULL OR auth.uid() = client_user_id)
  WITH CHECK (client_user_id IS NULL OR client_user_id = auth.uid());
