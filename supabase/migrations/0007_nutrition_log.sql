-- Catatan makanan dan minum harian, dibandingkan dengan target dari
-- Kalkulator Kalori.
--
-- Kolom serat, gula, natrium, dan berat porsi sudah disiapkan dari sekarang
-- meski form manualnya menandai itu opsional. Tujuannya supaya AI Food Scanner
-- nanti bisa langsung menulis ke tabel ini tanpa perlu migrasi lagi.

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Tanggal disimpan terpisah dari waktu supaya pengelompokan harian tidak
  -- bergeser gara-gara zona waktu.
  logged_on date not null,
  logged_at timestamptz not null default now(),

  name text not null,
  meal text not null default 'camilan'
    check (meal in ('sarapan', 'makan_siang', 'makan_malam', 'camilan')),

  serving_grams numeric check (serving_grams > 0),
  calories numeric not null check (calories >= 0),
  protein_g numeric not null default 0 check (protein_g >= 0),
  carbs_g numeric not null default 0 check (carbs_g >= 0),
  fat_g numeric not null default 0 check (fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sugar_g numeric check (sugar_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0),

  -- Diisi Food Scanner nanti: 0-100. Null berarti dicatat manual.
  confidence_percent numeric check (confidence_percent between 0 and 100),

  created_at timestamptz not null default now()
);

-- Satu baris per gelas, bukan satu baris per hari, supaya gelas terakhir bisa
-- dibatalkan dan waktunya tetap terekam.
create table if not exists public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  logged_on date not null,
  logged_at timestamptz not null default now(),
  ml int not null check (ml > 0),
  created_at timestamptz not null default now()
);

create index if not exists food_logs_user_date_idx
  on public.food_logs (user_id, logged_on desc);
create index if not exists water_logs_user_date_idx
  on public.water_logs (user_id, logged_on desc);

alter table public.food_logs enable row level security;
alter table public.water_logs enable row level security;

drop policy if exists "food_logs: owner full access" on public.food_logs;
create policy "food_logs: owner full access" on public.food_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "water_logs: owner full access" on public.water_logs;
create policy "water_logs: owner full access" on public.water_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
