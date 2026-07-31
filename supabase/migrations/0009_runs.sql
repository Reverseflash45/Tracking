-- Catatan lari beserta rutenya.
--
-- Rute disimpan sebagai jsonb di baris yang sama, bukan tabel titik terpisah.
-- Alasannya: rute selalu dibaca utuh bersama larinya dan tidak pernah
-- di-query per titik. Satu lari 5 km bisa berisi ratusan titik — sebagai tabel
-- terpisah itu ratusan baris per lari yang tidak pernah berguna sendirian.
--
-- Bentuk tiap elemen: {"lat": -6.2, "lng": 106.8, "t": 123456}
-- dengan `t` = milidetik sejak lari dimulai, tidak menghitung waktu jeda.

create table if not exists public.runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  started_at timestamptz not null,

  -- Durasi bergerak, bukan selisih jam mulai dan selesai: berhenti di lampu
  -- merah tidak boleh memperburuk pace-mu.
  duration_seconds int not null check (duration_seconds >= 0),

  distance_meters numeric not null default 0 check (distance_meters >= 0),

  route jsonb not null default '[]'::jsonb,

  notes text,
  created_at timestamptz not null default now()
);

create index if not exists runs_user_date_idx
  on public.runs (user_id, started_at desc);

alter table public.runs enable row level security;

drop policy if exists "runs: owner full access" on public.runs;
create policy "runs: owner full access" on public.runs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
