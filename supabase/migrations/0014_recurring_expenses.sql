-- Pengeluaran yang datang tiap bulan: kos, internet, langganan.
--
-- Tanpa ini "jatah harian" di halaman Keuangan menyesatkan. Dia membagi rata
-- sisa uangmu tanpa tahu Rp 800rb sudah dipesan untuk kos akhir bulan, jadi
-- angkanya selalu terlihat lebih longgar daripada kenyataan — persis di saat
-- kamu paling butuh angka yang benar.

create table if not exists public.recurring_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  name text not null,
  amount numeric not null check (amount > 0),
  category text not null,

  -- Tanggal jatuh tempo tiap bulan. Dibatasi 28 supaya tidak ada bulan yang
  -- kehilangan tanggalnya di Februari.
  due_day int not null check (due_day between 1 and 28),

  -- Dimatikan alih-alih dihapus kalau langganannya berhenti, supaya riwayat
  -- transaksi yang sudah tercatat tidak kehilangan asal-usulnya.
  active boolean not null default true,

  created_at timestamptz not null default now()
);

create index if not exists recurring_expenses_user_idx
  on public.recurring_expenses (user_id, active);

alter table public.recurring_expenses enable row level security;

drop policy if exists "recurring_expenses: owner full access" on public.recurring_expenses;
create policy "recurring_expenses: owner full access" on public.recurring_expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
