# Fitur "Foto makanan"

Fungsi ini menaksir isi piring dari foto. Dia memakai **Gemini** kalau secret
`GEMINI_API_KEY` ada (paket gratis Google AI Studio), dan **Claude** kalau
hanya `ANTHROPIC_API_KEY` yang diatur. App di HP tidak perlu tahu yang mana.

Status sekarang (Oktober 2026): sudah di-deploy dan memakai Gemini.

---

## Gemini (gratis)

1. Buat atau lihat key di https://aistudio.google.com/app/apikey
2. Pasang sebagai secret dan deploy:

   ```powershell
   supabase secrets set GEMINI_API_KEY=key-kamu
   supabase functions deploy foto-makanan --use-api
   supabase functions deploy baca-krs --use-api
   supabase functions deploy tanya --use-api
   ```

Kode pemanggil AI-nya dipakai bersama dengan "baca-krs" dan "tanya", di
[../_shared/ai.ts](../_shared/ai.ts). Karena itu, setelah mengubah file itu,
deploy ulang ketiga fungsinya.

Model yang dicoba berurutan: `gemini-flash-lite-latest`, lalu
`gemini-3.8-flash` kalau yang pertama sedang penuh. Flash-Lite didahulukan
karena pada uji Oktober 2026 hasilnya sama dengan Flash untuk foto nasi
goreng, tapi waktunya 3–10 detik. Flash sering penuh (503) dan butuh 15–60
detik. Daftarnya ada di `GEMINI_MODELS` di `_shared/ai.ts`. Google sering
mengganti nama model; kalau muncul error 404 "no longer available", ganti ke
model Flash terbaru dari halaman di atas.

Yang perlu diingat:
- **Kuota gratis bisa berubah** tanpa pemberitahuan. Kalau habis, app
  menampilkan "Kuota gratis Gemini hari ini habis" sampai besok — tidak ada
  tagihan.
- **Di paket gratis, Google boleh memakai foto yang dikirim** untuk
  memperbaiki produknya. Untuk foto makanan itu wajar; untuk data pribadi
  (seperti "Tanya data") sebaiknya tidak.
- Jangan memutar beberapa key dari akun berbeda untuk menambah kuota —
  itu melanggar ketentuan Google dan akunnya bisa diblokir.

## Claude (berbayar)

Hapus secret Gemini (`supabase secrets unset GEMINI_API_KEY`) dan atur
`ANTHROPIC_API_KEY` — lihat [../tanya/SETUP.md](../tanya/SETUP.md). Dengan
`claude-opus-5-5` pada effort `low`, kasarnya Rp 300–600 per foto. Langganan
Claude Pro tidak bisa dipakai: API ditagih terpisah lewat console.anthropic.com.

---

## Yang perlu diingat soal hasilnya

- Hasilnya **perkiraan**. Berat dari foto bisa meleset 20–30%, dan minyak,
  santan, atau gula yang larut tidak terlihat. Karena itu app selalu
  menampilkan hasilnya untuk diperiksa dulu, dan berat tiap item bisa diubah.
- Porsi yang biasa kamu catat ikut dikirim sebagai patokan, jadi taksirannya
  makin pas seiring waktu.
- Foto tidak disimpan di Supabase.
