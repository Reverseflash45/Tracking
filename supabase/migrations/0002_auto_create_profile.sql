-- Auto-create baris `profiles` saat user baru mendaftar, lewat trigger di auth.users.
-- Ini menghindari race condition RLS: signUp() belum tentu langsung punya sesi aktif
-- (mis. saat konfirmasi email masih diwajibkan), jadi insert profiles dari client bisa
-- ditolak RLS karena auth.uid() masih null. Trigger ini jalan dengan hak SECURITY DEFINER
-- sehingga tidak terpengaruh RLS dan selalu berhasil.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
