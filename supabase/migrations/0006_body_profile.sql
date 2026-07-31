-- Profil tubuh + riwayat berat badan, dasar untuk Kalkulator Kalori.
--
-- Berat badan sengaja dipisah ke tabelnya sendiri, bukan satu kolom di
-- body_profiles, supaya perubahan berat punya riwayat dan bisa digrafikkan
-- tanpa perlu migrasi lagi nanti.
--
-- Umur disimpan sebagai birth_date, bukan angka umur, supaya tidak basi
-- seiring waktu. Umur dihitung saat ditampilkan.

create table if not exists public.body_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  height_cm numeric not null check (height_cm > 0 and height_cm < 300),
  birth_date date not null,
  gender text not null check (gender in ('pria', 'wanita')),
  body_fat_percentage numeric check (body_fat_percentage > 0 and body_fat_percentage < 100),
  activity_level text not null default 'ringan'
    check (activity_level in ('sedentari', 'ringan', 'sedang', 'berat', 'sangat_berat')),
  goal text not null default 'maintenance'
    check (goal in ('cutting', 'maintenance', 'bulking', 'recomposition')),
  target_weight_kg numeric check (target_weight_kg > 0 and target_weight_kg < 500),
  target_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  logged_on date not null,
  weight_kg numeric not null check (weight_kg > 0 and weight_kg < 500),
  created_at timestamptz not null default now(),
  -- Satu catatan berat per hari; input ulang di hari yang sama menimpa.
  unique (user_id, logged_on)
);

create index if not exists weight_logs_user_date_idx
  on public.weight_logs (user_id, logged_on desc);

alter table public.body_profiles enable row level security;
alter table public.weight_logs enable row level security;

drop policy if exists "body_profiles: owner full access" on public.body_profiles;
create policy "body_profiles: owner full access" on public.body_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "weight_logs: owner full access" on public.weight_logs;
create policy "weight_logs: owner full access" on public.weight_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
