-- Catatan tidur harian.
--
-- Kalkulator Kalori sudah menghitung target tidur 7-9 jam, tapi sampai
-- sekarang tidak ada tempat mencatatnya: app memberi target lalu tidak pernah
-- bertanya lagi. Ini menutup lingkaran itu.
--
-- Disimpan per tanggal bangun, bukan per tanggal tidur. Tidur jam 1 pagi lalu
-- bangun jam 8 itu "tidur untuk hari ini", dan menaruhnya di tanggal kemarin
-- membuat setiap begadang tercatat di hari yang salah.

create table if not exists public.sleep_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  logged_on date not null,

  -- Lama tidur dalam jam. numeric supaya 6,5 jam bisa dicatat apa adanya.
  -- Dibatasi 24 karena lebih dari itu pasti salah ketik.
  hours numeric not null check (hours > 0 and hours <= 24),

  -- Kualitas 1-5, opsional. Lama tidur saja tidak bercerita banyak — tujuh jam
  -- yang terbangun lima kali bukan tujuh jam yang sama.
  quality int check (quality between 1 and 5),

  note text,
  created_at timestamptz not null default now(),

  unique (user_id, logged_on)
);

create index if not exists sleep_logs_user_date_idx
  on public.sleep_logs (user_id, logged_on desc);

alter table public.sleep_logs enable row level security;

drop policy if exists "sleep_logs: owner full access" on public.sleep_logs;
create policy "sleep_logs: owner full access" on public.sleep_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
