-- Kendaraan: servis dan pajak.
--
-- Dua hal yang kalau terlewat langsung berbiaya — pajak telat kena denda, oli
-- telat merusak mesin — dan keduanya jatuh tempo dalam hitungan bulan sampai
-- tahun. Terlalu panjang untuk diingat sendiri, terlalu pendek untuk aman.

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  name text not null,
  type text not null default 'motor' check (type in ('motor', 'mobil')),

  -- Nomor polisi. Dipakai saat mengurus pajak, dan saat ada dua kendaraan
  -- yang namanya mirip.
  plate text,
  year int check (year between 1900 and 2200),

  -- Odometer terakhir yang dicatat beserta kapan dicatatnya. Keduanya harus
  -- ada bersama: angka tanpa tanggal tidak bisa dipakai menghitung apa pun.
  odometer_km int check (odometer_km >= 0),
  odometer_on date,

  -- Jatuh tempo pajak tahunan dan ganti plat lima tahunan, dua-duanya dari
  -- STNK. Yang lima tahunan paling sering terlewat justru karena jaraknya jauh.
  tax_due_on date,
  plate_due_on date,

  created_at timestamptz not null default now(),

  constraint odometer_lengkap check (
    (odometer_km is null and odometer_on is null)
    or (odometer_km is not null and odometer_on is not null)
  )
);

create table if not exists public.vehicle_services (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,

  kind text not null default 'lainnya' check (kind in (
    'oli', 'oliGardan', 'servisRutin', 'busi',
    'kampasRem', 'rantai', 'ban', 'aki', 'lainnya'
  )),

  done_on date not null,

  -- Null berarti odometernya tidak sempat dicatat. Kalau begitu, jarak ke
  -- servis berikutnya memang tidak bisa dihitung — dan itu dikatakan, bukan
  -- ditebak.
  odometer_km int check (odometer_km >= 0),

  -- Null berarti biayanya tidak dicatat. Ini bukan gratis, dan jumlah yang
  -- seperti ini dilaporkan terpisah supaya totalnya tidak terlihat lebih
  -- murah daripada kenyataan.
  cost numeric check (cost >= 0),

  note text,
  created_at timestamptz not null default now()
);

create index if not exists vehicles_user_idx on public.vehicles (user_id);
create index if not exists vehicle_services_vehicle_idx
  on public.vehicle_services (vehicle_id, done_on desc);

alter table public.vehicles enable row level security;
alter table public.vehicle_services enable row level security;

drop policy if exists "vehicles: owner full access" on public.vehicles;
create policy "vehicles: owner full access" on public.vehicles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "vehicle_services: owner full access" on public.vehicle_services;
create policy "vehicle_services: owner full access" on public.vehicle_services
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
