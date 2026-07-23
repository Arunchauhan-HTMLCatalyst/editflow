-- Migration: Add Monthly Retainer / Folder Projects support
-- Adds payment_type, is_folder, and parent_id columns to the projects table.

-- 1. Add payment_type column (project_basis or monthly)
ALTER TABLE projects ADD COLUMN IF NOT EXISTS payment_type TEXT NOT NULL DEFAULT 'project_basis';

-- 2. Add is_folder column (true for monthly folder projects)
ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_folder BOOLEAN NOT NULL DEFAULT false;

-- 3. Add parent_id column (links sub-projects to their parent folder)
ALTER TABLE projects ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES projects(id) ON DELETE CASCADE;

-- 4. Add check constraint for payment_type values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'projects_payment_type_check'
  ) THEN
    ALTER TABLE projects ADD CONSTRAINT projects_payment_type_check
      CHECK (payment_type IN ('project_basis', 'monthly'));
  END IF;
END $$;

-- 5. Add index on parent_id for fast sub-project lookups
CREATE INDEX IF NOT EXISTS idx_projects_parent_id ON projects(parent_id) WHERE parent_id IS NOT NULL;

-- 6. Update RLS policies to allow sub-projects to be accessed
-- Sub-projects inherit the same user_id as their parent, so existing RLS policies
-- based on user_id will work automatically. No changes needed.
