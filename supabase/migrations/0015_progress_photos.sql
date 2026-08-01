-- Foto progres badan.
--
-- PRASYARAT: bikin dulu bucket 'progress-photos' lewat Supabase Dashboard
-- (Storage -> New bucket -> nama 'progress-photos'). **JANGAN dicentang
-- "Public bucket"** — beda dari 'avatars'. Foto badan itu jauh lebih pribadi
-- daripada foto profil, dan bucket publik berarti siapa pun yang menebak
-- URL-nya bisa melihatnya tanpa login. App membacanya lewat signed URL.

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  taken_on date not null,

  -- Path di bucket, bukan URL. URL bertanda tangan itu kedaluwarsa, jadi
  -- menyimpannya berarti menyimpan tautan yang pasti mati.
  storage_path text not null,

  -- Berat saat foto diambil, kalau ada. Foto tanpa angka susah dibandingkan.
  weight_kg numeric check (weight_kg > 0 and weight_kg < 500),

  note text,
  created_at timestamptz not null default now()
);

create index if not exists progress_photos_user_date_idx
  on public.progress_photos (user_id, taken_on desc);

alter table public.progress_photos enable row level security;

drop policy if exists "progress_photos: owner full access" on public.progress_photos;
create policy "progress_photos: owner full access" on public.progress_photos
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Storage: hanya pemiliknya, termasuk untuk membaca. Tidak ada policy "public
-- read" di sini, sengaja.
-- Path konvensi: {user_id}/{uuid}.jpg
drop policy if exists "progress photos: owner read" on storage.objects;
create policy "progress photos: owner read"
  on storage.objects for select
  using (
    bucket_id = 'progress-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "progress photos: owner insert" on storage.objects;
create policy "progress photos: owner insert"
  on storage.objects for insert
  with check (
    bucket_id = 'progress-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "progress photos: owner delete" on storage.objects;
create policy "progress photos: owner delete"
  on storage.objects for delete
  using (
    bucket_id = 'progress-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
