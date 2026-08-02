-- Tugas yang datang tiap minggu: laporan praktikum, kuis mingguan, jurnal.
--
-- Tanpa ini "laporan praktikum tiap Senin" berarti kamu membuat tugas yang sama
-- dengan tangan 16 kali per semester — dan yang terlewat bukan tugas yang tidak
-- kamu kerjakan, tapi tugas yang lupa kamu catat.

create table if not exists public.recurring_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid references public.courses (id) on delete set null,

  title text not null,
  description text,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),

  -- 1 = Senin ... 7 = Minggu, mengikuti DateTime.weekday di Dart.
  weekday int not null check (weekday between 1 and 7),

  -- Jam deadline dalam menit dari tengah malam. Default 23.59.
  deadline_minute int not null default 1439 check (deadline_minute between 0 and 1439),

  -- Dimatikan alih-alih dihapus kalau mata kuliahnya selesai, supaya tugas
  -- yang sudah terlanjur dibuat tidak kehilangan asal-usulnya.
  active boolean not null default true,

  created_at timestamptz not null default now()
);

create index if not exists recurring_tasks_user_idx
  on public.recurring_tasks (user_id, active);

alter table public.recurring_tasks enable row level security;

drop policy if exists "recurring_tasks: owner full access" on public.recurring_tasks;
create policy "recurring_tasks: owner full access" on public.recurring_tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Jejak asal-usul di tabel tugas.
--
-- `recurring_on` menyimpan tanggal kejadian yang diwakili baris ini. Bersama
-- indeks unik di bawah, itulah yang membuat pembuatan otomatis aman diulang:
-- dua HP yang membuka app bersamaan tidak bisa menghasilkan tugas kembar,
-- karena yang kedua ditolak database, bukan sekadar dihindari oleh kode.
alter table public.tasks
  add column if not exists recurring_id uuid references public.recurring_tasks (id) on delete set null;

alter table public.tasks
  add column if not exists recurring_on date;

-- Sengaja tanpa klausa WHERE meski hanya baris ber-recurring_id yang perlu
-- dijaga: Postgres menganggap NULL berbeda satu sama lain, jadi tugas biasa
-- (yang kedua kolomnya null) tetap boleh sebanyak apa pun. Indeks parsial akan
-- terlihat lebih rapi, tapi ON CONFLICT tidak bisa menunjuknya lewat PostgREST,
-- dan itu justru menghapus pengaman yang jadi alasan indeks ini ada.
create unique index if not exists tasks_recurring_occurrence_idx
  on public.tasks (recurring_id, recurring_on);
