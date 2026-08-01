-- Hari istirahat: hari yang sengaja dikosongkan untuk pemulihan.
--
-- Disimpan di tabelnya sendiri, bukan sebagai sesi workout kosong. Hari
-- istirahat bukan latihan: dia tidak boleh menambah volume, tidak boleh
-- terhitung sebagai sesi di Wrapped, dan tidak boleh ikut jadi "hari olahraga"
-- waktu membandingkan data di halaman Pola dan Tanya Data. Satu-satunya yang
-- dia sentuh adalah streak.
--
-- Kalau ditumpangkan ke workout_sessions, semua angka di atas ikut naik tanpa
-- kamu benar-benar berlatih — dan itu persis jenis kebohongan yang bikin
-- catatan jadi tidak ada gunanya.

create table if not exists public.rest_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  rest_on date not null,
  note text,

  created_at timestamptz not null default now(),

  -- Satu hari cukup ditandai sekali.
  unique (user_id, rest_on)
);

create index if not exists rest_days_user_date_idx
  on public.rest_days (user_id, rest_on desc);

alter table public.rest_days enable row level security;

drop policy if exists "rest_days: owner full access" on public.rest_days;
create policy "rest_days: owner full access" on public.rest_days
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
