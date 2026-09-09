-- Program latihan yang sedang dijalani.
--
-- Yang disimpan di sini cuma pilihannya, bukan isi programnya. Daftar
-- gerakannya sama untuk semua orang, jadi dia ditulis sebagai const Dart dan
-- ikut ke dalam APK — halamannya tetap terbuka tanpa sinyal, dan tidak ada
-- query jaringan untuk membaca sesuatu yang tidak pernah berubah per akun.
--
-- Satu baris per user: kamu menjalani satu program pada satu waktu. Menjalani
-- dua program sekaligus bukan hal yang perlu didukung — itu justru cara paling
-- umum untuk tidak menyelesaikan keduanya.
--
-- Jalankan file ini di Supabase SQL Editor.

create table if not exists public.workout_programs (
  user_id uuid primary key references auth.users (id) on delete cascade,

  program text not null default 'naik_berat' check (program in ('naik_berat')),

  -- Punya kursi kokoh atau tidak. Ini yang menentukan enam gerakan mana yang
  -- dipakai, bukan sekadar catatan.
  equipment text not null check (equipment in ('kursi', 'tanpa_kursi')),

  -- Dipakai menghitung sudah berjalan berapa minggu.
  started_on date not null default current_date,

  updated_at timestamptz not null default now()
);

alter table public.workout_programs enable row level security;

drop policy if exists "workout_programs owner" on public.workout_programs;
create policy "workout_programs owner" on public.workout_programs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
