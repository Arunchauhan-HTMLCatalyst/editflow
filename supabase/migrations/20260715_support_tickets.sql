-- Create support_tickets table
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

-- Allow users to insert their own tickets
CREATE POLICY "Users can create support tickets"
  ON support_tickets FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Allow users to view their own tickets
CREATE POLICY "Users can view own support tickets"
  ON support_tickets FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Allow admin edge functions (service role or authenticated admins) to perform actions
CREATE POLICY "Admin full access"
  ON support_tickets FOR ALL TO service_role USING (true);
