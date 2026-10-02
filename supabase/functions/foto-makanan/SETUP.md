# Mengaktifkan "Foto makanan"

Kodenya sudah lengkap, tapi tombol **Foto makanan** baru berfungsi setelah
fungsi ini di-deploy ke Supabase. Sampai saat itu, app menampilkan pesan
"Fitur ini belum aktif".

Langkahnya sama dengan fitur "Tanya data" — lihat
[../tanya/SETUP.md](../tanya/SETUP.md) untuk detail tiap langkah.

1. **API key Anthropic** — Langkah 1 di SETUP "tanya". Kalau "Tanya data"
   sudah jalan, lewati: kedua fungsi memakai secret yang sama.
2. **Supabase CLI** terpasang dan ter-link ke proyekmu — Langkah 2.
3. **Secret** `ANTHROPIC_API_KEY` sudah diatur — Langkah 3.
4. **Deploy:**

   ```powershell
   supabase functions deploy foto-makanan
   ```

Lalu buka app: **Workout → Nutrisi → ikon kamera**, atau tombol
**Foto makanan** di form catat makanan.

---

## Soal biaya

Foto diperkecil di HP ke sisi terpanjang 1024 px sebelum dikirim, jadi satu
foto sekitar 1.000–1.400 token gambar. Dengan `claude-opus-5-5` pada effort
`low` seperti di kode, kasarnya **Rp 300–600 per foto** — saldo 5 dolar cukup
untuk sekitar 150–250 foto. Analisis ulang dengan keterangan dihitung sebagai
foto baru.

Kalau terlalu mahal untuk tiga kali makan sehari, ganti model di
[index.ts](index.ts) menjadi `claude-sonnet-5-5` — kira-kira separuh harganya.
Kalau taksirannya terasa ceroboh, naikkan `effort` ke `"medium"` (lebih teliti,
lebih mahal).

## Yang perlu diingat

- Hasilnya **perkiraan**. Berat dari foto bisa meleset 20–30%, dan minyak,
  santan, atau gula yang larut tidak terlihat. Karena itu app selalu
  menampilkan hasilnya untuk diperiksa dulu, dan berat tiap item bisa diubah.
- Foto dikirim ke Anthropic untuk dianalisis dan tidak disimpan di Supabase.
