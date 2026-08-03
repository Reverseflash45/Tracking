-- Watchlist: film, series, anime, buku, dan komik.
--
-- Bentuk (film/series/buku/komik) dan asal (anime/Hollywood/Korea/...) disimpan
-- di dua kolom terpisah, bukan satu kolom kategori. Anime bisa berupa film
-- maupun series, dan komik asal Jepang, Korea, atau China punya sebutan
-- sendiri-sendiri — satu kolom campuran tidak bisa menyatakan itu tanpa jadi
-- dua puluh pilihan yang saling tumpang tindih.

create table if not exists public.media_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  title text not null,

  kind text not null default 'film'
    check (kind in ('film', 'series', 'buku', 'komik')),

  origin text not null default 'lainnya'
    check (origin in (
      'anime', 'hollywood', 'korea', 'jepang',
      'china', 'indonesia', 'barat', 'lainnya'
    )),

  status text not null default 'rencana'
    check (status in ('rencana', 'jalan', 'selesai', 'berhenti')),

  -- Tahun rilis. Berguna membedakan dua judul yang sama; banyak sekali film
  -- yang dibuat ulang dengan nama persis sama.
  year int check (year between 1888 and 2200),

  -- Episode/halaman/chapter yang sudah dilewati.
  progress int not null default 0 check (progress >= 0),

  -- Null berarti belum tahu totalnya, dan itu beda dari nol: series yang masih
  -- tayang memang belum punya angka ini. Tanpa perbedaan itu, bilah progresnya
  -- akan menampilkan 0% untuk sesuatu yang sebenarnya tidak terhitung.
  total int check (total > 0),

  -- 1-10. Null berarti belum dinilai, bukan nol.
  rating int check (rating between 1 and 10),

  url text,
  note text,

  -- Terisi saat statusnya jadi selesai. Yang selesai tanpa tanggal tidak ikut
  -- dihitung sebagai "selesai tahun ini" — tidak ada cara jujur menebaknya.
  finished_on date,

  created_at timestamptz not null default now()
);

create index if not exists media_items_user_idx
  on public.media_items (user_id, status);

alter table public.media_items enable row level security;

drop policy if exists "media_items: owner full access" on public.media_items;
create policy "media_items: owner full access" on public.media_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
