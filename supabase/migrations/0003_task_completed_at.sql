-- Dipakai untuk menghitung Deadline Streak: menandai kapan tugas benar-benar
-- diselesaikan, supaya bisa dibandingkan dengan deadline (tepat waktu vs telat).
alter table public.tasks add column if not exists completed_at timestamptz;
