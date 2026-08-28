-- Rutinitas harian: jadwal pribadi berulang tiap minggu.
--
-- Tabel sendiri, bukan menumpang class_schedules. Bentuknya memang berbeda:
-- jadwal kuliah selalu punya jam selesai, selalu menempel ke satu mata kuliah,
-- dan lahir dari KRS. "Bangun, timbang badan" tidak punya satu pun dari itu.
--
-- Jalankan file ini di Supabase SQL Editor.

create table if not exists public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- 1 = Senin ... 7 = Minggu, mengikuti DateTime.weekday seperti tabel jadwal.
  day_of_week int not null check (day_of_week between 1 and 7),

  start_time time not null,

  -- Boleh kosong. "05:45 Bangun" adalah satu titik waktu, bukan rentang, dan
  -- memaksa jam selesai membuat kamu mengarang angka yang tidak kamu maksud.
  end_time time,

  title text not null,

  category text not null default 'lainnya' check (category in (
    'bangun', 'makan', 'kerja', 'workout', 'ibadah', 'santai', 'tidur', 'lainnya'
  )),

  note text,
  created_at timestamptz not null default now()
);

create index if not exists routines_user_day_idx
  on public.routines (user_id, day_of_week, start_time);

alter table public.routines enable row level security;

drop policy if exists "routines owner" on public.routines;
create policy "routines owner" on public.routines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
