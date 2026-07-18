-- =============================================================
-- Migration: Add replies, reactions, and resolved status to review_comments
-- =============================================================

-- Add columns
ALTER TABLE public.review_comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.review_comments(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS reactions JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_resolved BOOLEAN NOT NULL DEFAULT false;

-- Create index for parent_id lookups
CREATE INDEX IF NOT EXISTS idx_review_comments_parent_id ON public.review_comments(parent_id);

-- Add UPDATE policies
CREATE POLICY "Allow authenticated users to update review_comments"
  ON public.review_comments FOR UPDATE TO authenticated
  USING (
    video_id IN (
      SELECT rv.id FROM public.review_videos rv
      JOIN public.reviews r ON rv.review_id = r.id
      JOIN public.projects p ON r.project_id = p.id
      WHERE p.user_id = auth.uid() OR p.client_id IN (
        SELECT id FROM public.clients WHERE client_user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Allow public UPDATE on review_comments via valid token"
  ON public.review_comments FOR UPDATE
  USING (
    video_id IN (
      SELECT rv.id FROM public.review_videos rv
      JOIN public.review_shares rs ON rv.review_id = rs.review_id
      WHERE rs.token = current_setting('request.headers', true)::json->>'x-share-token'
      AND (rs.expires_at IS NULL OR rs.expires_at > now())
    )
  );
