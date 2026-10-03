# Fitur "Tanya data" (ketik bebas)

Status sekarang (Oktober 2026): sudah di-deploy dan memakai **Gemini** (paket
gratis Google AI Studio), lewat jalur AI bersama di
[../_shared/ai.ts](../_shared/ai.ts) — sama dengan foto makanan dan baca KRS.
Pertanyaan siap pakai di halaman Tanya tidak memakai fungsi ini sama sekali;
jawabannya dihitung di HP.

---

## Kenapa harus lewat Edge Function

API key yang ditaruh langsung di kode Flutter **ikut terbundel ke dalam APK**.
APK itu arsip biasa; siapa pun yang mengunduhnya bisa membongkar dan membaca
isinya dalam hitungan menit, lalu menghabiskan kuota atau tagihanmu.

Edge Function memindahkan key ke server Supabase. App cuma mengirim
pertanyaan; key-nya tidak pernah menyentuh HP siapa pun.

```
HP kamu  ──(pertanyaan + ringkasan data)──►  Edge Function  ──(+ API key)──►  Gemini / Claude
         ◄──────────(jawaban)──────────────                ◄────────────────
```

---

## Penyedia AI

Fungsi ini memakai Gemini kalau secret `GEMINI_API_KEY` ada, dan Claude kalau
hanya `ANTHROPIC_API_KEY` yang diatur. Cara memasang key Gemini ada di
[../foto-makanan/SETUP.md](../foto-makanan/SETUP.md); deploy ulang dengan:

```powershell
supabase functions deploy tanya --use-api
```

Untuk memakai Claude (berbayar): hapus secret Gemini
(`supabase secrets unset GEMINI_API_KEY`), atur `ANTHROPIC_API_KEY` dari
console.anthropic.com → API Keys, lalu deploy ulang. Dengan `claude-opus-5-5`
pada effort `low`, kasarnya Rp 250–450 per pertanyaan. Langganan Claude Pro
tidak bisa dipakai untuk API. Pasang spend limit di console (Billing → Limits).

---

## Kalau error

| Yang muncul di app | Artinya |
|---|---|
| `Fungsi "tanya" belum ada di Supabase` | Belum di-deploy, atau salah project ref |
| `Belum ada API key AI` | Secret belum diatur. Deploy ulang setelah menyimpannya |
| `API key Gemini ditolak` | Key salah salin, atau sudah dihapus di AI Studio |
| `Kuota gratis Gemini hari ini habis` | Coba lagi besok — tidak ada tagihan |
| `Layanan AI sedang penuh` | Kedua model Gemini sedang sibuk. Coba sebentar lagi |
| `Butuh login` | Sesi app-mu kedaluwarsa. Logout lalu login lagi |

Log lengkap: dashboard Supabase → Edge Functions → tanya → Logs.

---

## Pengaman yang sudah terpasang

- Pertanyaan dibatasi 500 karakter, ringkasan 12.000 karakter.
- Yang dikirim RINGKASAN 30 hari (total, rata-rata, lima tugas terdekat),
  bukan data mentah — catatan, dokumen, dan transaksi satu per satu tidak ikut.

## Soal privasi

Di paket gratis, Google boleh memakai yang dikirim untuk memperbaiki
produknya. Untuk ringkasan angka seperti ini risikonya kecil, tapi tetap saja
datanya keluar dari HP-mu. Halaman Tanya menyebutkannya sebelum kamu bertanya.
Kalau tidak nyaman, pakai pertanyaan siap pakai saja — itu tidak mengirim apa
pun.
