-- Add unique constraint to utr in premium_upgrade_requests
ALTER TABLE public.premium_upgrade_requests DROP CONSTRAINT IF EXISTS unique_utr;
ALTER TABLE public.premium_upgrade_requests ADD CONSTRAINT unique_utr UNIQUE (utr);
