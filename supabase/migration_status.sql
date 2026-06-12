-- Migration: Update project status values to new 4-status system
-- Run this in the Supabase SQL editor

-- 1. Update existing rows to new status values
UPDATE projects SET status = 'yet_to_start' WHERE status = 'created';
UPDATE projects SET status = 'in_process' WHERE status = 'in_progress';
UPDATE projects SET status = 'revision_pending' WHERE status = 'review';
UPDATE projects SET status = 'revision_pending' WHERE status = 'revision';
UPDATE projects SET status = 'completed' WHERE status = 'paid';

-- 2. Drop old CHECK constraint and add new one with updated default
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;
ALTER TABLE projects ADD CONSTRAINT projects_status_check
  CHECK (status IN ('yet_to_start', 'in_process', 'revision_pending', 'completed'));
ALTER TABLE projects ALTER COLUMN status SET DEFAULT 'yet_to_start';
