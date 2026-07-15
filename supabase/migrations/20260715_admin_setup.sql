-- =============================================================
-- Migration: Admin Setup
-- Add user roles, suspension tracking, and global settings.
-- =============================================================

-- 1. Add admin & suspension columns to profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false;

-- 2. Create system settings table
CREATE TABLE IF NOT EXISTS public.system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on system settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Allow anyone (authenticated or anonymous) to view settings (e.g. to read maintenance status or announcement banner)
CREATE POLICY "Allow public read access to system settings"
  ON public.system_settings FOR SELECT USING (true);

-- 3. Populate default settings config
INSERT INTO public.system_settings (key, value) VALUES
  ('announcement', '{"text": "", "visible": false}'::jsonb),
  ('maintenance', '{"enabled": false, "message": "EditFlow is currently undergoing scheduled maintenance. Please check back later."}'::jsonb),
  ('support', '{"email": "support@acsoft.online", "telegram": ""}'::jsonb)
ON CONFLICT (key) DO NOTHING;
