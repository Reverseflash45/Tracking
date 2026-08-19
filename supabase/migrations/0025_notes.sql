-- Catatan bebas: hal-hal yang tidak berbentuk tugas, transaksi, atau jadwal.
--
-- Tanpa tempat seperti ini, satu-satunya cara mencatat sesuatu di app ini
-- adalah memaksanya jadi tugas berdeadline — dan "password wifi kos" bukan
-- tugas, apalagi tugas yang jatuh tempo minggu depan.
--
-- Jalankan file ini di Supabase SQL Editor.

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Judul boleh kosong. Catatan cepat sering langsung isinya, dan memaksa
  -- judul membuat orang berhenti sebelum sempat mencatat apa pun. Kalau
  -- kosong, baris pertama isinya yang dipakai sebagai judul di daftar.
  title text,
  body text not null default '',

  pinned boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Daftar catatan selalu diurut yang terbaru diubah lebih dulu.
create index if not exists notes_user_updated_idx
  on public.notes (user_id, updated_at desc);

alter table public.notes enable row level security;

drop policy if exists "notes owner" on public.notes;
create policy "notes owner" on public.notes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
