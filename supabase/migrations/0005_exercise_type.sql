-- Tipe latihan menggantikan boolean is_cardio.
--
-- Alasannya: tiap tipe punya sumbu progressive overload yang berbeda —
-- latihan beban naik kg, bodyweight naik ke variasi yang lebih sulit,
-- isometrik naik durasi tahanan, cardio naik durasi/jarak. Satu boolean
-- tidak bisa membedakan keempatnya.
--
-- Aman dijalankan ulang. Backfill jalan sebelum kolom lama dihapus, jadi
-- data sesi workout yang sudah ada tidak hilang.

alter table public.workout_exercises
  add column if not exists exercise_type text;

-- Backfill dari kolom lama selama kolomnya masih ada.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'workout_exercises'
      and column_name = 'is_cardio'
  ) then
    update public.workout_exercises
      set exercise_type = case when is_cardio then 'cardio' else 'beban' end
      where exercise_type is null;
  end if;
end $$;

-- Baris apa pun yang belum terisi (mis. kolom lama sudah hilang) dianggap beban.
update public.workout_exercises set exercise_type = 'beban' where exercise_type is null;

alter table public.workout_exercises alter column exercise_type set default 'beban';
alter table public.workout_exercises alter column exercise_type set not null;

alter table public.workout_exercises
  drop constraint if exists workout_exercises_exercise_type_check;
alter table public.workout_exercises
  add constraint workout_exercises_exercise_type_check
  check (exercise_type in ('beban', 'bodyweight', 'isometrik', 'cardio'));

-- Posisi di tangga progresi bodyweight (0 = langkah pertama).
alter table public.workout_exercises
  add column if not exists progression_level int not null default 0;

-- Tahanan isometrik diukur dalam detik; duration_minutes tetap untuk cardio.
alter table public.workout_exercises
  add column if not exists duration_seconds int;

-- Kolom lama sudah tidak dipakai kode mana pun setelah backfill di atas.
alter table public.workout_exercises drop column if exists is_cardio;
