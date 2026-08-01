-- Catatan keuangan: pemasukan dan pengeluaran harian.
--
-- Nilai uang disimpan sebagai numeric, bukan float. Rupiah memang tidak pakai
-- sen, tapi float tetap berbahaya untuk uang — penjumlahan berulang bisa
-- menggeser total beberapa rupiah dan tidak ada alasan menerima itu.

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  occurred_on date not null,

  kind text not null check (kind in ('pemasukan', 'pengeluaran')),
  category text not null,

  amount numeric not null check (amount > 0),

  -- Nama tempat, diisi manual atau dari hasil baca struk.
  merchant text,
  note text,

  -- 'manual' atau 'struk'. Dipakai untuk menandai catatan yang angkanya berasal
  -- dari pembacaan foto, karena itu lebih mungkin salah daripada ketikan.
  source text not null default 'manual' check (source in ('manual', 'struk')),

  created_at timestamptz not null default now()
);

-- Anggaran bulanan. Satu baris per user; bulan tidak dipisah karena uang saku
-- jarang berubah tiap bulan, dan mengisinya ulang tiap bulan cuma merepotkan.
create table if not exists public.finance_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  monthly_budget numeric check (monthly_budget >= 0),

  -- Tanggal kiriman uang bulanan datang, 1-28. Dibatasi 28 supaya tidak ada
  -- bulan yang kehilangan tanggalnya di Februari.
  payday_day int check (payday_day between 1 and 28),

  updated_at timestamptz not null default now()
);

create index if not exists transactions_user_date_idx
  on public.transactions (user_id, occurred_on desc);

alter table public.transactions enable row level security;
alter table public.finance_settings enable row level security;

drop policy if exists "transactions: owner full access" on public.transactions;
create policy "transactions: owner full access" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "finance_settings: owner full access" on public.finance_settings;
create policy "finance_settings: owner full access" on public.finance_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
