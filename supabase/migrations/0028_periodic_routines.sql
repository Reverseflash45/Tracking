-- Rutinitas berkala: hal yang perlu diulang tiap beberapa hari, bukan tiap
-- hari tertentu dalam seminggu.
--
-- Contohnya absen akun supaya tidak hangus tiap 25 hari, ganti sprei tiap 14
-- hari, atau isi ulang kuota tiap 30 hari. Tidak bisa menumpang tabel
-- routines: jadwalnya bukan "tiap Senin", melainkan "25 hari sejak terakhir
-- kamu melakukannya" — dan titik mulainya bergeser tiap kali kamu
-- menandainya selesai, termasuk kalau kamu telat.
--
-- Jalankan file ini di Supabase SQL Editor. Aman dijalankan ulang.

create table if not exists public.periodic_routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  title text not null,

  -- Dibatasi sepuluh tahun. Lebih dari itu sudah bukan rutinitas, dan angka
  -- yang salah ketik (250 alih-alih 25) lebih cepat ketahuan.
  interval_days int not null check (interval_days between 1 and 3650),

  -- Jatuh tempo berikutnya = last_done_on + interval_days. Disimpan tanggal
  -- terakhirnya, bukan tanggal jatuh temponya, supaya mengubah jarak hari
  -- langsung menggeser jatuh tempo tanpa perlu dihitung ulang di mana-mana.
  last_done_on date not null default current_date,

  -- Jam pengingat khusus. Null berarti ikut jam pengingat umum di Profil.
  remind_at time,

  note text,
  created_at timestamptz not null default now()
);

create index if not exists periodic_routines_user_idx
  on public.periodic_routines (user_id, last_done_on);

alter table public.periodic_routines enable row level security;

drop policy if exists "periodic_routines owner" on public.periodic_routines;
create policy "periodic_routines owner" on public.periodic_routines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- RIWAYAT
--
-- Menandai selesai = menambah satu baris di sini, bukan mengubah
-- periodic_routines langsung. Alasannya antrean offline di app: antrean itu
-- sengaja hanya menyimpan insert, karena insert tidak pernah bertabrakan.
-- Dengan begini tombol "Sudah" tetap jalan tanpa sinyal, dan tombol "Sudah"
-- di notifikasi (yang berjalan tanpa membuka app) memakai jalur yang sama.
--
-- last_done_on di tabel induk diperbarui oleh trigger di bawah.

create table if not exists public.periodic_routine_logs (
  -- Dibuat di HP, bukan default server: catatan yang masih di antrean offline
  -- harus bisa dibatalkan, dan untuk itu id-nya harus sudah ada sebelum
  -- terkirim.
  id uuid primary key,
  routine_id uuid not null references public.periodic_routines (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,

  done_on date not null,

  -- Diisi trigger dari keadaan induk saat baris ini masuk. due_on dipakai
  -- menghitung telat; previous_done_on dipakai memulihkan induk kalau baris
  -- ini dihapus (tombol Batal).
  due_on date,
  previous_done_on date,

  created_at timestamptz not null default now()
);

create index if not exists periodic_routine_logs_routine_idx
  on public.periodic_routine_logs (routine_id, done_on desc);

alter table public.periodic_routine_logs enable row level security;

drop policy if exists "periodic_routine_logs owner" on public.periodic_routine_logs;
create policy "periodic_routine_logs owner" on public.periodic_routine_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- Sebelum masuk: catat tanggal pelaksanaan sebelumnya dan jatuh temponya.
--
-- Biasanya itu cukup last_done_on induk saat ini. Pengecualiannya catatan
-- offline yang terkirim belakangan padahal tanggalnya lebih lama dari catatan
-- yang sudah ada: tanggal sebelumnya harus dicari menurut urutan waktu, bukan
-- urutan masuk — kalau tidak, membatalkannya memulihkan tanggal yang salah.
create or replace function public.periodic_routine_logs_before_insert()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  induk public.periodic_routines;
  sebelumnya date;
begin
  select * into induk from public.periodic_routines where id = new.routine_id;
  if not found then
    return new;
  end if;

  if new.done_on >= induk.last_done_on then
    sebelumnya := induk.last_done_on;
  else
    select max(done_on) into sebelumnya
      from public.periodic_routine_logs
     where routine_id = new.routine_id and done_on <= new.done_on;

    -- Tidak ada catatan yang lebih lama: pakai tanggal awal sebelum riwayat
    -- dimulai, yang tersimpan di catatan paling awal.
    if sebelumnya is null then
      select previous_done_on into sebelumnya
        from public.periodic_routine_logs
       where routine_id = new.routine_id
       order by done_on, created_at
       limit 1;
    end if;
    sebelumnya := coalesce(sebelumnya, induk.last_done_on);
  end if;

  new.previous_done_on := sebelumnya;
  new.due_on := sebelumnya + induk.interval_days;
  return new;
end;
$$;

-- Sesudah masuk: majukan tanggal terakhir. greatest() supaya catatan offline
-- yang baru terkirim belakangan tidak memundurkan tanggal yang lebih baru.
create or replace function public.periodic_routine_logs_after_insert()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.periodic_routines
     set last_done_on = greatest(last_done_on, new.done_on)
   where id = new.routine_id;
  return new;
end;
$$;

-- Sesudah dihapus: tanggal terakhir kembali ke catatan terbaru yang tersisa,
-- atau ke tanggal sebelum catatan ini masuk kalau tidak ada lagi.
create or replace function public.periodic_routine_logs_after_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.periodic_routines
     set last_done_on = coalesce(
       (select max(done_on) from public.periodic_routine_logs where routine_id = old.routine_id),
       old.previous_done_on,
       last_done_on
     )
   where id = old.routine_id;
  return old;
end;
$$;

drop trigger if exists periodic_routine_logs_before_insert on public.periodic_routine_logs;
create trigger periodic_routine_logs_before_insert
  before insert on public.periodic_routine_logs
  for each row execute function public.periodic_routine_logs_before_insert();

drop trigger if exists periodic_routine_logs_after_insert on public.periodic_routine_logs;
create trigger periodic_routine_logs_after_insert
  after insert on public.periodic_routine_logs
  for each row execute function public.periodic_routine_logs_after_insert();

drop trigger if exists periodic_routine_logs_after_delete on public.periodic_routine_logs;
create trigger periodic_routine_logs_after_delete
  after delete on public.periodic_routine_logs
  for each row execute function public.periodic_routine_logs_after_delete();
