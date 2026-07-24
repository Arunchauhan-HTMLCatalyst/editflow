-- 1. Add upi_id column to profiles table if not exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS upi_id TEXT;

-- 2. Create RPC function to securely update payment received amount and status from client portal
CREATE OR REPLACE FUNCTION public.client_pay_project(target_project_id UUID, client_uid UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_project_user_id UUID;
  v_client_id UUID;
  v_price NUMERIC;
BEGIN
  -- Verify project exists and the client_uid is connected to the client associated with the project
  SELECT p.user_id, p.client_id, p.price INTO v_project_user_id, v_client_id, v_price
  FROM public.projects p
  JOIN public.clients c ON p.client_id = c.id
  WHERE p.id = target_project_id AND c.client_user_id = client_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unauthorized or project not found';
  END IF;

  -- Update received_amount to equal price and transition completed projects to paid status
  UPDATE public.projects
  SET received_amount = price,
      status = CASE WHEN status = 'completed' THEN 'paid' ELSE status END,
      updated_at = now()
  WHERE id = target_project_id;

  -- Log payment received activity
  INSERT INTO public.activities (user_id, type, description, reference_id, reference_type)
  VALUES (v_project_user_id, 'payment_received', 'Client confirmed payment of remaining amount', target_project_id, 'project');
END;
$$;
