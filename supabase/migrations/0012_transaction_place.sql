-- Rincian tempat belanja: jenisnya, nama tokonya, dan barang yang dibeli.
--
-- Sebelumnya cuma ada satu kolom 'merchant' yang harus menampung semuanya.
-- Akibatnya "ShopeeFood" dan "Martabak telor istimewa" berebut satu kolom,
-- dan tidak ada satu pun pertanyaan berguna yang bisa dijawab dari situ.
--
-- 'merchant' sengaja tidak diganti nama, cuma diberi arti yang lebih sempit
-- (nama toko). Mengganti nama kolom yang sudah berisi data itu risiko yang
-- tidak dibayar apa-apa.

alter table public.transactions
  add column if not exists place_type text,
  add column if not exists product_name text;

-- Empat kombinasi dari dua sumbu: toko/resto dan offline/online. Dibatasi
-- daftar tetap supaya bisa dikelompokkan; kolomnya boleh kosong karena tidak
-- semua pengeluaran punya tempat (transfer, iuran, parkir).
alter table public.transactions
  drop constraint if exists transactions_place_type_check;

alter table public.transactions
  add constraint transactions_place_type_check
  check (
    place_type is null
    or place_type in ('toko_offline', 'toko_online', 'resto_offline', 'resto_online')
  );
