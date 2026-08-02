-- Target lintas domain.
--
-- App ini mengukur banyak sekali hal tapi tidak pernah menuntut apa pun. Semua
-- angkanya bercerita tentang apa yang sudah terjadi; tidak ada satu pun yang
-- kamu janjikan ke dirimu sendiri lebih dulu. Tabel ini yang membedakan
-- pencatatan dari komitmen.
--
-- Nilai kemajuannya sengaja TIDAK disimpan di sini. Semuanya dihitung ulang di
-- HP dari data yang sudah ada — lari, sesi latihan, tugas, tidur, transaksi.
-- Menyimpan angka progres berarti punya dua sumber kebenaran yang bisa
-- berselisih, dan yang salah selalu yang tersimpan.

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  title text not null,

  -- Nama metrik mengikuti enum GoalMetric di Dart. Sengaja tanpa check
  -- constraint: menambah metrik baru nanti tidak boleh butuh migrasi, dan nama
  -- yang tidak dikenal diabaikan diam-diam waktu dibaca.
  metric text not null,

  target_value numeric not null check (target_value > 0),

  -- 'mingguan' dan 'bulanan' berulang: jendelanya dihitung dari hari ini, jadi
  -- target "lari 20 km tiap bulan" ikut berpindah sendiri ke bulan berikutnya.
  -- 'sekali' memakai start_date dan end_date apa adanya.
  period text not null default 'bulanan' check (period in ('mingguan', 'bulanan', 'sekali')),

  start_date date,
  end_date date,

  archived boolean not null default false,
  created_at timestamptz not null default now(),

  -- Target sekali jalan tanpa tanggal tidak punya arti: tidak ada jendela yang
  -- bisa dihitung, dan kemajuannya akan selamanya nol.
  constraint goals_sekali_butuh_tanggal check (
    period <> 'sekali' or (start_date is not null and end_date is not null)
  )
);

create index if not exists goals_user_idx on public.goals (user_id, archived);

alter table public.goals enable row level security;

drop policy if exists "goals: owner full access" on public.goals;
create policy "goals: owner full access" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
