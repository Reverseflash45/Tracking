-- Nilai akhir resmi dari KHS.
--
-- Migrasi 0018 menghitung nilai dari komponen (Tugas/UTS/UAS) — itu perkiraanmu
-- sendiri selama semester berjalan. KHS memberi hurufnya langsung, dan huruf itu
-- yang resmi.
--
-- Disimpan sebagai HURUF, bukan diubah jadi angka. Membalik "A" jadi skor berarti
-- memilih satu angka dari rentang (85–100) dan menuliskannya seolah-olah itu
-- nilaimu — mengarang, dengan bentuk yang terlihat seperti data.
--
-- Kalau kolom ini terisi, dia menang atas hitungan komponen: hasil resmi
-- mengalahkan perkiraan.

alter table public.courses
  add column if not exists final_letter text;
