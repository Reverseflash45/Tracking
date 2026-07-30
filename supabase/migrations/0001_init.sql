-- Fase 1: profiles, akademik (courses, class_schedules, tasks), workout
-- (workout_sessions, workout_exercises). Jalankan file ini di Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  lecturer text,
  created_at timestamptz not null default now()
);

create table if not exists public.class_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  day_of_week int not null check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  room text,
  is_phl boolean not null default false,
  specific_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid references public.courses (id) on delete set null,
  title text not null,
  description text,
  deadline timestamptz not null,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done')),
  created_at timestamptz not null default now()
);

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_name text not null,
  weight_kg numeric,
  sets int,
  reps int,
  duration_minutes int,
  is_cardio boolean not null default false,
  notes text
);

-- Row Level Security: setiap user hanya boleh mengakses baris miliknya sendiri.
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.class_schedules enable row level security;
alter table public.tasks enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_exercises enable row level security;

create policy "profiles: owner full access" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "courses: owner full access" on public.courses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "class_schedules: owner full access" on public.class_schedules
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "tasks: owner full access" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "workout_sessions: owner full access" on public.workout_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "workout_exercises: owner full access" on public.workout_exercises
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
