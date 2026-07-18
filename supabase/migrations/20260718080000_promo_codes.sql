-- Create promo_codes table
CREATE TABLE IF NOT EXISTS public.promo_codes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    code text UNIQUE NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    max_uses integer DEFAULT 1, -- NULL means unlimited
    used_count integer DEFAULT 0 NOT NULL,
    duration_days integer DEFAULT 30 NOT NULL, -- 1 month default
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Create promo_code_redemptions table
CREATE TABLE IF NOT EXISTS public.promo_code_redemptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    promo_code_id uuid REFERENCES public.promo_codes(id) ON DELETE CASCADE NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_promo UNIQUE (user_id, promo_code_id)
);

-- Enable RLS
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_code_redemptions ENABLE ROW LEVEL SECURITY;

-- Admin can read/write everything on promo_codes
CREATE POLICY "Admin full access on promo_codes" ON public.promo_codes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid() AND public.profiles.role = 'admin'
        )
    );

-- Admin can read/write everything on redemptions
CREATE POLICY "Admin full access on redemptions" ON public.promo_code_redemptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid() AND public.profiles.role = 'admin'
        )
    );

-- Users can read their own redemptions
CREATE POLICY "Users can read their own redemptions" ON public.promo_code_redemptions
    FOR SELECT USING (user_id = auth.uid());

-- PostgreSQL function for secure atomicity (RPC)
CREATE OR REPLACE FUNCTION public.redeem_promo_code(p_user_id uuid, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_record RECORD;
    v_new_until timestamp with time zone;
    v_current_until timestamp with time zone;
BEGIN
    -- 1. Find and lock the promo code row to prevent race conditions
    SELECT * INTO v_code_record
    FROM public.promo_codes
    WHERE upper(trim(code)) = upper(trim(p_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid promo code');
    END IF;

    -- 2. Verify if code is active
    IF NOT v_code_record.is_active THEN
        RETURN jsonb_build_object('success', false, 'message', 'This promo code is inactive');
    END IF;

    -- 3. Verify if code is expired
    IF v_code_record.expires_at IS NOT NULL AND v_code_record.expires_at < now() THEN
        RETURN jsonb_build_object('success', false, 'message', 'This promo code has expired');
    END IF;

    -- 4. Verify if max uses exceeded
    IF v_code_record.max_uses IS NOT NULL AND v_code_record.used_count >= v_code_record.max_uses THEN
        RETURN jsonb_build_object('success', false, 'message', 'This promo code has reached its maximum use limit');
    END IF;

    -- 5. Verify if user has already redeemed this specific code
    IF EXISTS (
        SELECT 1 FROM public.promo_code_redemptions
        WHERE user_id = p_user_id AND promo_code_id = v_code_record.id
    ) THEN
        RETURN jsonb_build_object('success', false, 'message', 'You have already redeemed this promo code');
    END IF;

    -- 6. Insert redemption record
    INSERT INTO public.promo_code_redemptions (user_id, promo_code_id)
    VALUES (p_user_id, v_code_record.id);

    -- 7. Update usage count
    UPDATE public.promo_codes
    SET used_count = used_count + 1
    WHERE id = v_code_record.id;

    -- 8. Fetch current subscription duration if any
    SELECT premium_until INTO v_current_until
    FROM public.profiles
    WHERE id = p_user_id;

    -- Calculate new expiration
    IF v_current_until IS NOT NULL AND v_current_until > now() THEN
        v_new_until := v_current_until + (v_code_record.duration_days || ' days')::interval;
    ELSE
        v_new_until := now() + (v_code_record.duration_days || ' days')::interval;
    END IF;

    -- 9. Update user premium status
    UPDATE public.profiles
    SET 
        is_premium = true,
        premium_until = v_new_until,
        premium_started_at = COALESCE(premium_started_at, now()),
        premium_plan_type = 'Promo Code'
    WHERE id = p_user_id;

    -- Return success payload
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Promo code redeemed successfully!', 
        'premium_until', to_char(v_new_until, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
