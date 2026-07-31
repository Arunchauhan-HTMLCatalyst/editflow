-- Drop existing select policies if they exist to prevent conflicts
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are readable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow select for authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;

-- Create policy to allow all authenticated users to read profiles
-- This ensures clients can read their freelancer's name and UPI ID details, and vice versa.
CREATE POLICY "Allow authenticated users to read profiles" 
ON public.profiles 
FOR SELECT 
TO authenticated 
USING (true);
