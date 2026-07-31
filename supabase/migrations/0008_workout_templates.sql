-- Template workout: rutinitas tersimpan yang bisa dipakai ulang, mis. "Push A".
--
-- Sengaja dipisah dari `workout_sessions`, bukan pakai flag `is_template` di
-- tabel sesi. Alasannya: template tidak punya tanggal, tidak boleh ikut masuk
-- hitungan streak, volume, Wrapped, maupun grafik progres. Satu flag di tabel
-- sesi berarti tiap query di app harus ingat menyaringnya — cepat atau lambat
-- ada yang lupa, dan angkanya diam-diam salah.

create table if not exists public.workout_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_template_exercises (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.workout_templates (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Urutan latihan di dalam template; tanpa ini urutannya ditentukan database.
  position int not null default 0,

  exercise_name text not null,
  exercise_type text not null default 'beban'
    check (exercise_type in ('beban', 'bodyweight', 'isometrik', 'cardio')),

  weight_kg numeric,
  sets int,
  reps int,
  duration_minutes int,
  duration_seconds int,
  progression_level int not null default 0,

  -- Lama istirahat antar set, dipakai sebagai nilai awal rest timer.
  rest_seconds int check (rest_seconds > 0),

  notes text,
  created_at timestamptz not null default now()
);

create index if not exists workout_templates_user_idx
  on public.workout_templates (user_id, created_at desc);
create index if not exists workout_template_exercises_template_idx
  on public.workout_template_exercises (template_id, position);

alter table public.workout_templates enable row level security;
alter table public.workout_template_exercises enable row level security;

drop policy if exists "workout_templates: owner full access" on public.workout_templates;
create policy "workout_templates: owner full access" on public.workout_templates
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "workout_template_exercises: owner full access"
  on public.workout_template_exercises;
create policy "workout_template_exercises: owner full access"
  on public.workout_template_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
