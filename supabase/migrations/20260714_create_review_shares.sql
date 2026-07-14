-- =============================================================
-- Migration: Create review_shares table and RLS policies
-- =============================================================

CREATE TABLE IF NOT EXISTS public.review_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ, -- null = never expires
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast token lookups
CREATE INDEX IF NOT EXISTS idx_review_shares_token ON public.review_shares(token);

-- Enable RLS
ALTER TABLE public.review_shares ENABLE ROW LEVEL SECURITY;

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE review_shares;

-- RLS Policies for review_shares
CREATE POLICY "Allow public select of share by token"
  ON public.review_shares FOR SELECT
  USING (true); -- Public can lookup tokens

CREATE POLICY "Allow authenticated users to manage own shares"
  ON public.review_shares FOR ALL TO authenticated
  USING (
    review_id IN (
      SELECT r.id FROM public.reviews r
      JOIN public.projects p ON r.project_id = p.id
      WHERE p.user_id = auth.uid() OR p.client_id IN (
        SELECT id FROM public.clients WHERE client_user_id = auth.uid()
      )
    )
  );

-- RLS Policies for reviews (Allow public SELECT if they have a valid token)
CREATE POLICY "Allow public SELECT on reviews via valid token"
  ON public.reviews FOR SELECT
  USING (
    id IN (
      SELECT review_id FROM public.review_shares
      WHERE token = current_setting('request.headers', true)::json->>'x-share-token'
      AND (expires_at IS NULL OR expires_at > now())
    )
  );

-- RLS Policies for review_videos (Allow public SELECT if they have a valid token)
CREATE POLICY "Allow public SELECT on review_videos via valid token"
  ON public.review_videos FOR SELECT
  USING (
    review_id IN (
      SELECT review_id FROM public.review_shares
      WHERE token = current_setting('request.headers', true)::json->>'x-share-token'
      AND (expires_at IS NULL OR expires_at > now())
    )
  );

-- RLS Policies for review_comments (Allow public SELECT & INSERT if they have a valid token)
CREATE POLICY "Allow public SELECT on review_comments via valid token"
  ON public.review_comments FOR SELECT
  USING (
    video_id IN (
      SELECT rv.id FROM public.review_videos rv
      JOIN public.review_shares rs ON rv.review_id = rs.review_id
      WHERE rs.token = current_setting('request.headers', true)::json->>'x-share-token'
      AND (rs.expires_at IS NULL OR rs.expires_at > now())
    )
  );

CREATE POLICY "Allow public INSERT on review_comments via valid token"
  ON public.review_comments FOR INSERT
  WITH CHECK (
    video_id IN (
      SELECT rv.id FROM public.review_videos rv
      JOIN public.review_shares rs ON rv.review_id = rs.review_id
      WHERE rs.token = current_setting('request.headers', true)::json->>'x-share-token'
      AND (rs.expires_at IS NULL OR rs.expires_at > now())
    )
  );
