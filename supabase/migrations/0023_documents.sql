-- Dokumen penting dan masa berlakunya.
--
-- Sekali diisi, mengingatkan bertahun-tahun tanpa disentuh lagi. SIM yang
-- telat sehari tidak bisa diperpanjang — harus tes ulang dari nol.
--
-- Catatan keamanan: tabel ini bisa memuat nomor KTP, SIM, dan BPJS. Dia
-- dilindungi RLS seperti tabel lain, jadi baris milik akun lain tidak bisa
-- dibaca. Yang belum ada adalah kunci di sisi aplikasi — siapa pun yang
-- memegang HP dalam keadaan terbuka bisa melihatnya. Nomornya ditampilkan
-- tersamar secara bawaan, dan harus ditekan dulu untuk terbaca penuh.

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  name text not null,

  kind text not null default 'lainnya' check (kind in (
    'ktp', 'sim', 'stnk', 'paspor', 'bpjs',
    'npwp', 'kartuMahasiswa', 'asuransi', 'lainnya'
  )),

  number text,

  issued_on date,
  expires_on date,

  -- Penanda terpisah, bukan sekadar expires_on kosong: "seumur hidup" dan
  -- "belum diisi" dua keadaan berbeda. Yang kedua perlu ditagih, yang pertama
  -- tidak.
  no_expiry boolean not null default false,

  note text,
  created_at timestamptz not null default now(),

  constraint tempo_tidak_bertentangan check (
    not (no_expiry and expires_on is not null)
  )
);

create index if not exists documents_user_idx on public.documents (user_id, expires_on);

alter table public.documents enable row level security;

drop policy if exists "documents: owner full access" on public.documents;
create policy "documents: owner full access" on public.documents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
