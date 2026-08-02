-- Wishlist: barang yang ingin kamu beli.
--
-- Bedanya dengan catatan biasa di HP: app ini tahu berapa yang masuk dan keluar
-- tiap bulan, jadi dia bisa menjawab pertanyaan yang sebenarnya kamu punya —
-- bukan "apa saja yang aku mau", tapi "kapan aku bisa beli ini".

create table if not exists public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  name text not null,

  -- Null berarti belum tahu harganya. Ini beda dari nol, dan bedanya penting:
  -- barang tanpa harga tidak boleh ikut menghitung total atau perkiraan waktu,
  -- karena hasilnya akan terlihat lebih murah daripada kenyataan.
  price numeric check (price >= 0),

  -- Mengikuti enum TxCategory di Dart, supaya transaksi yang dibuat waktu
  -- barangnya jadi dibeli langsung masuk ke kategori yang benar.
  category text not null default 'belanja',

  priority text not null default 'sedang' check (priority in ('rendah', 'sedang', 'tinggi')),

  -- Uang yang sudah kamu sisihkan khusus untuk barang ini.
  saved numeric not null default 0 check (saved >= 0),

  url text,
  note text,

  -- Kapan kamu ingin sudah memilikinya. Opsional.
  target_date date,

  -- Terisi kalau sudah dibeli. Barang yang sudah dibeli tidak dihapus supaya
  -- kamu masih bisa melihat apa yang dulu kamu inginkan dan jadi kamu ambil.
  bought_on date,

  created_at timestamptz not null default now()
);

create index if not exists wishlist_items_user_idx
  on public.wishlist_items (user_id, bought_on);

alter table public.wishlist_items enable row level security;

drop policy if exists "wishlist_items: owner full access" on public.wishlist_items;
create policy "wishlist_items: owner full access" on public.wishlist_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
