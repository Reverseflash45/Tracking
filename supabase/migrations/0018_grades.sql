-- Nilai dan IPK.
--
-- App ini mengurus jadwal, tugas, dan deadline, tapi tidak tahu apa pun tentang
-- hasilnya. Untuk app mahasiswa itu lubang yang cukup besar — dan begitu nilai
-- masuk, pertanyaan yang selama ini tidak bisa dijawab siapa pun jadi bisa:
-- apakah mata kuliah yang tugasnya sering telat nilainya memang lebih jelek.
-- `tasks.completed_at` sudah ada sejak migrasi 0003 untuk itu.

alter table public.courses
  add column if not exists sks int check (sks between 0 and 12);

-- Bebas formatnya, mis. "2026/2027 Ganjil" atau "Semester 5". Sengaja teks
-- bebas: penamaan semester berbeda-beda tiap kampus, dan memaksakan satu format
-- cuma membuat orang mengetik sesuatu yang tidak dia pakai.
alter table public.courses
  add column if not exists semester text;

create table if not exists public.grade_components (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,

  name text not null,

  -- Persentase komponen terhadap nilai akhir, mis. UTS 30.
  weight numeric not null check (weight > 0 and weight <= 100),

  -- Null berarti belum keluar nilainya. Ini beda arti dari nol, dan bedanya
  -- penting: komponen yang belum dinilai tidak boleh ikut menyeret rata-rata
  -- ke bawah seolah-olah kamu dapat nol.
  score numeric check (score >= 0 and score <= 100),

  created_at timestamptz not null default now()
);

create index if not exists grade_components_course_idx
  on public.grade_components (user_id, course_id);

alter table public.grade_components enable row level security;

drop policy if exists "grade_components: owner full access" on public.grade_components;
create policy "grade_components: owner full access" on public.grade_components
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
