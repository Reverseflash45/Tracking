# Fitur "Baca KRS dengan AI"

Status sekarang (Oktober 2026): sudah di-deploy dan memakai Gemini, lewat jalur
AI bersama di [../_shared/ai.ts](../_shared/ai.ts). Key-nya sama dengan foto
makanan — tidak ada yang perlu dipasang lagi. Lihat
[../foto-makanan/SETUP.md](../foto-makanan/SETUP.md) untuk memasang atau
mengganti key.

Deploy ulang setelah mengubah kodenya:

```powershell
supabase functions deploy baca-krs --use-api
```

## Cara kerjanya

1. App memperkecil foto atau screenshot KRS (sisi terpanjang 2000 px) lalu
   mengirimnya ke fungsi ini.
2. AI menyalin tabelnya ke daftar jadwal: nama, kode, kelas, SKS, hari, jam,
   ruang, dosen. Mata kuliah yang bertemu dua kali seminggu jadi dua baris.
3. Fungsi ini membuang baris yang hari atau jamnya tidak masuk akal, lalu app
   menampilkan semuanya untuk diperiksa. Tidak ada yang langsung tersimpan.

Kalau AI tidak bisa dipakai — offline, kuota habis, gambar terlalu besar —
app otomatis membaca foto yang sama dengan pembaca on-device lama (OCR +
penebak pola). Saklar "Baca dengan AI" di halamannya mematikan AI sepenuhnya
kalau kamu tidak mau fotonya keluar dari HP.

## Yang perlu diingat

- KRS memuat nama dan NIM. Di paket gratis, Google boleh memakai gambar yang
  dikirim untuk memperbaiki produknya. Matikan saklarnya kalau keberatan.
- Diuji Oktober 2026 dengan KRS tiruan yang selnya terpecah dua baris dan satu
  mata kuliah tanpa jadwal: semua baris benar, sekitar 5 detik, dan mata kuliah
  tanpa jadwal disebut di catatan, bukan dikarang.
