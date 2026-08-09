-- Tiga hal sekaligus, karena ketiganya menyentuh tabel akademik yang sama:
-- tugas pribadi, kode mata kuliah & kelas, dan absensi kuliah.

-- ---------------------------------------------------------------------------
-- 1. Tugas pribadi
-- ---------------------------------------------------------------------------
-- `course_id` di tabel tasks sebenarnya sudah boleh kosong sejak awal, jadi
-- tugas tanpa mata kuliah selama ini sudah bisa disimpan. Yang tidak ada adalah
-- pembedanya.
--
-- Sengaja kolom sendiri, bukan disimpulkan dari `course_id is null`. Keduanya
-- bukan hal yang sama: tugas kuliah yang mata kuliahnya belum sempat dipilih
-- juga punya course_id kosong, dan kalau disimpulkan, dia akan diam-diam
-- berpindah ke daftar pribadi.
alter table public.tasks
  add column if not exists kind text not null default 'kuliah'
  check (kind in ('kuliah', 'pribadi'));

-- ---------------------------------------------------------------------------
-- 2. Kode mata kuliah dan kode kelas
-- ---------------------------------------------------------------------------
-- Pembaca KRS sudah menemukan keduanya sejak dulu — dia harus menemukannya
-- justru untuk bisa membuangnya dari nama mata kuliah. Yang belum ada cuma
-- tempat menyimpannya.
--
-- Kode mata kuliah menempel di mata kuliahnya (SIC204 tetap SIC204 di kelas
-- mana pun), sedangkan kode kelas menempel di jadwalnya: satu mata kuliah bisa
-- dibuka untuk beberapa kelas, dan yang membedakan justru barisnya di jadwal.
alter table public.courses add column if not exists code text;
alter table public.class_schedules add column if not exists class_code text;

-- ---------------------------------------------------------------------------
-- 3. Jumlah pertemuan satu semester
-- ---------------------------------------------------------------------------
-- Dipakai menghitung sisa jatah tidak masuk. Boleh kosong, dan kalau kosong
-- jatahnya memang tidak dihitung — bukan ditebak 14 atau 16. Jumlah pertemuan
-- berbeda tiap kampus dan tiap mata kuliah, dan angka jatah bolos yang salah
-- lebih berbahaya daripada tidak ada angka sama sekali.
alter table public.courses
  add column if not exists total_meetings int check (total_meetings > 0);

-- Batas maksimal ketidakhadiran, dalam persen. Kebanyakan kampus memakai 25%,
-- tapi ada yang 20% dan ada yang menghitung per mata kuliah, jadi angkanya bisa
-- diubah sendiri per mata kuliah.
alter table public.courses
  add column if not exists max_absence_percent int
  check (max_absence_percent between 1 and 100);

-- ---------------------------------------------------------------------------
-- 4. Absensi
-- ---------------------------------------------------------------------------
-- Satu baris per pertemuan yang dicatat. Yang tidak dicatat berarti tidak
-- dicatat — bukan otomatis dianggap hadir dan bukan otomatis dianggap bolos.
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,

  -- Jadwal asalnya, kalau dicatat dari halaman jadwal. Boleh kosong dan boleh
  -- hilang: jadwal bisa dihapus atau diubah di tengah semester, dan riwayat
  -- kehadiran tidak boleh ikut terhapus bersamanya.
  schedule_id uuid references public.class_schedules (id) on delete set null,

  meeting_date date not null,

  status text not null check (status in ('hadir', 'izin', 'sakit', 'alpa')),

  -- Alasan, materi yang terlewat, atau titipan teman. Ini yang membuat catatan
  -- kehadiran berguna berbulan-bulan kemudian, bukan cuma jadi angka.
  note text,

  created_at timestamptz not null default now(),

  -- Satu mata kuliah cuma boleh punya satu catatan per tanggal. Tanpa ini,
  -- menekan tombol dua kali diam-diam menggandakan hitungannya.
  unique (user_id, course_id, meeting_date)
);

create index if not exists attendance_user_course_idx
  on public.attendance (user_id, course_id, meeting_date desc);

alter table public.attendance enable row level security;

drop policy if exists "attendance owner" on public.attendance;
create policy "attendance owner" on public.attendance
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
