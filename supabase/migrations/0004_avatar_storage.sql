-- Foto profil: kolom avatar_url + policy RLS untuk bucket storage 'avatars'.
--
-- PRASYARAT: bucket 'avatars' harus dibuat dulu lewat Supabase Dashboard
-- (Storage -> New bucket -> nama 'avatars', aktifkan "Public bucket"),
-- karena insert langsung ke storage.buckets lewat SQL Editor biasanya
-- ditolak oleh permission Supabase.

alter table public.profiles add column if not exists avatar_url text;

-- Path konvensi: {user_id}/avatar.<ext> — folder pertama harus sama dengan auth.uid().
drop policy if exists "avatars: public read" on storage.objects;
create policy "avatars: public read"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars: owner insert" on storage.objects;
create policy "avatars: owner insert"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars: owner update" on storage.objects;
create policy "avatars: owner update"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars: owner delete" on storage.objects;
create policy "avatars: owner delete"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
