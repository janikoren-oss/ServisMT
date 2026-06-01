-- ============================================================
-- ServisMT — Supabase Database Setup
-- Zaženi v Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. TABELE

CREATE TABLE IF NOT EXISTS public.services (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  serial_number TEXT NOT NULL,
  service_type  TEXT NOT NULL DEFAULT 'hardware',
  priority      TEXT NOT NULL DEFAULT 'normal',
  status        TEXT NOT NULL DEFAULT 'active',
  request_date  DATE,
  received_date DATE,
  due_date      DATE,
  returned_date DATE,
  return_note   TEXT DEFAULT '',
  location      TEXT DEFAULT '',
  service_partner TEXT DEFAULT 'Billy POS d.o.o.',
  error_description TEXT DEFAULT '',
  technician_notes  TEXT DEFAULT '',
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  role      TEXT NOT NULL DEFAULT 'user'
);

CREATE TABLE IF NOT EXISTS public.app_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);

INSERT INTO public.app_settings (key, value) VALUES
  ('hw_days',       '14'),
  ('sw_days',       '7'),
  ('reminder_days', '2'),
  ('teams_url',     '')
ON CONFLICT (key) DO NOTHING;

-- 2. ROW LEVEL SECURITY

ALTER TABLE public.services     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Services: vsi avtenticirani uporabniki
CREATE POLICY "svc_select" ON public.services FOR SELECT TO authenticated USING (true);
CREATE POLICY "svc_insert" ON public.services FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "svc_update" ON public.services FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "svc_delete" ON public.services FOR DELETE TO authenticated
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Profiles
CREATE POLICY "prof_select" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "prof_update" ON public.profiles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- App settings: beri vsi, piši samo admin
CREATE POLICY "set_select" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "set_all"    ON public.app_settings FOR ALL    TO authenticated
  USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 3. TRIGGER — avtomatično ustvari profil ob registraciji

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  ) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 4. USTVARI UPORABNIKE
-- Po zagonu tega skriptza pojdi v Supabase Dashboard:
--   Authentication → Users → Add User
--
--   Ime: Jani Koren         E-pošta: jani.koren@[tvoja-domena]   Geslo: ServisMT2024!
--   Ime: Sandra Stanivuković E-pošta: sandra.s@[tvoja-domena]    Geslo: ServisMT2024!
--   Ime: Boštjan Jazbec     E-pošta: bostjan.j@[tvoja-domena]   Geslo: ServisMT2024!
--   Ime: Dragan Denić       E-pošta: dragan.d@[tvoja-domena]    Geslo: ServisMT2024!
--
-- Nato nastavi profile in vloge s spodnjim SQL-om.
-- ZAMENJAJ UUIDs z dejanskimi ID-ji iz auth.users tabele!
-- ============================================================

-- Primer (zamenjaj UUID z dejanskim):
-- UPDATE public.profiles SET full_name = 'Jani Koren',          role = 'admin' WHERE id = 'UUID-jani';
-- UPDATE public.profiles SET full_name = 'Sandra Stanivuković', role = 'user'  WHERE id = 'UUID-sandra';
-- UPDATE public.profiles SET full_name = 'Boštjan Jazbec',      role = 'user'  WHERE id = 'UUID-bostjan';
-- UPDATE public.profiles SET full_name = 'Dragan Denić',        role = 'user'  WHERE id = 'UUID-dragan';

-- Ali pa prikaži vse ustvarjene profile in ID-je:
SELECT u.id, u.email, p.full_name, p.role
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at;
