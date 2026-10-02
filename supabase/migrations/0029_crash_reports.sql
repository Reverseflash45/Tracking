-- Laporan error dari app.
--
-- Tanpa layanan luar (Sentry dkk.): error ditangkap di HP, ditampung di berkas
-- lokal, lalu dikirim ke sini begitu ada sinyal dan sesi login. Lihat isinya
-- di Supabase Dashboard → Table Editor → crash_reports.
--
-- Hanya error Dart/Flutter. Crash di kode native Android (jarang di app ini)
-- tidak tertangkap — untuk itu tetap butuh layanan seperti Firebase
-- Crashlytics.
--
-- Jalankan file ini di Supabase SQL Editor. Aman dijalankan ulang.

create table if not exists public.crash_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Saat error terjadi di HP, bukan saat terkirim — bisa berselisih berhari-hari
  -- kalau HP-nya lama offline.
  occurred_at timestamptz not null,

  app_version text,
  platform text,

  -- Dibatasi supaya satu error berulang tidak memenuhi database.
  error text not null check (length(error) <= 2000),
  stack text check (length(stack) <= 8000),

  -- Di mana error-nya tertangkap, misal "building Widget" atau "zone".
  context text check (length(context) <= 500),

  -- Berapa kali error yang sama muncul sebelum terkirim.
  occurrences int not null default 1 check (occurrences >= 1),

  created_at timestamptz not null default now()
);

create index if not exists crash_reports_time_idx
  on public.crash_reports (occurred_at desc);

alter table public.crash_reports enable row level security;

-- Pengguna hanya bisa mengirim dan melihat laporannya sendiri. Kamu sebagai
-- pemilik proyek tetap melihat semuanya lewat Dashboard (service role).
drop policy if exists "crash_reports insert own" on public.crash_reports;
create policy "crash_reports insert own" on public.crash_reports
  for insert with check (auth.uid() = user_id);

drop policy if exists "crash_reports select own" on public.crash_reports;
create policy "crash_reports select own" on public.crash_reports
  for select using (auth.uid() = user_id);
