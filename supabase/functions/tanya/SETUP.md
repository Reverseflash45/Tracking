# Mengaktifkan "Tanya Data"

Kodenya sudah lengkap, tapi fiturnya **belum jalan** sampai kamu menyelesaikan
empat langkah di bawah. Semuanya harus kamu yang kerjakan — dua di antaranya
butuh akunmu sendiri, dan satu butuh kartu kredit.

Perkiraan waktu: 15–20 menit.

---

## Kenapa harus ada Edge Function

API key yang ditaruh langsung di kode Flutter **ikut terbundel ke dalam APK**.
APK itu arsip biasa; siapa pun yang mengunduhnya bisa membongkar dan membaca
isinya dalam hitungan menit. Key yang bocor bisa dipakai orang lain, dan
tagihannya atas namamu.

Edge Function memindahkan key ke server Supabase. App cuma mengirim
pertanyaan; key-nya tidak pernah menyentuh HP siapa pun.

```
HP kamu  ──(pertanyaan + ringkasan data)──►  Edge Function  ──(+ API key)──►  Claude
         ◄──────────(jawaban)──────────────                ◄────────────────
```

---

## Langkah 1 — Dapatkan API key Anthropic

1. Buka **https://console.anthropic.com**, daftar atau masuk.
2. Masuk ke **Billing**, isi saldo. **Ini berbayar** — tidak ada tier gratis
   untuk API. Isi 5 dolar dulu untuk mencoba; itu cukup untuk ribuan
   pertanyaan dengan pengaturan yang ada di kode ini.
3. Masuk ke **API Keys** → **Create Key**. Salin sekarang juga —
   **key-nya cuma ditampilkan sekali**.

Key-nya berbentuk `sk-ant-api03-...`.

> ⚠️ Jangan tempel key ini ke chat, ke commit, ke `.env`, atau ke mana pun di
> dalam folder proyek. Satu-satunya tempatnya di Langkah 3.

---

## Langkah 2 — Pasang Supabase CLI

**Windows (PowerShell):**

```powershell
winget install Supabase.CLI
```

Cek berhasil:

```powershell
supabase --version
```

Lalu masuk dan hubungkan ke proyekmu:

```powershell
supabase login
supabase link --project-ref <PROJECT_REF>
```

`<PROJECT_REF>` itu potongan acak di URL dashboard Supabase-mu:
`https://supabase.com/dashboard/project/`**`abcdefghijklmnop`** ← itu dia.

---

## Langkah 3 — Simpan API key sebagai secret

Jalankan dari folder proyek:

```powershell
supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-kunci-aslimu-di-sini
```

Cek sudah masuk (nilainya tidak akan ditampilkan — memang begitu seharusnya):

```powershell
supabase secrets list
```

Bisa juga lewat dashboard: **Project Settings → Edge Functions → Secrets**.

---

## Langkah 4 — Deploy fungsinya

```powershell
supabase functions deploy tanya
```

Kalau sukses, Supabase menampilkan URL fungsinya. Selesai — buka app,
**Profil → Tanya Data**, lalu coba salah satu pertanyaan contoh.

---

## Kalau error

| Yang muncul di app | Artinya |
|---|---|
| `Fungsi "tanya" belum ada di Supabase` | Langkah 4 belum jalan, atau salah project ref |
| `ANTHROPIC_API_KEY belum diatur` | Langkah 3 belum jalan. Deploy ulang setelah menyimpan secret |
| `API key ditolak` | Key salah salin, atau sudah kamu hapus di console |
| `Terlalu banyak permintaan` | Kena rate limit. Tunggu semenit |
| `Butuh login` | Sesi app-mu kedaluwarsa. Logout lalu login lagi |

Lihat log lengkap kalau masih bingung:

```powershell
supabase functions logs tanya
```

---

## Soal biaya

Tiap pertanyaan mengirim ringkasan 30 hari terakhir (bukan data mentah — itu
sengaja, supaya murah) plus jawabannya. Kasarnya beberapa ratus rupiah per
pertanyaan.

Dua pengaman sudah dipasang di kode:

- Pertanyaan dibatasi 500 karakter, ringkasan 12.000 karakter.
- `effort` disetel `low` — pertanyaan sederhana atas ringkasan yang sudah
  dihitung app tidak butuh penalaran dalam. Kalau jawabannya terasa dangkal,
  naikkan ke `"medium"` di [index.ts](index.ts).

Pasang **spend limit** di console Anthropic (Billing → Limits) supaya ada batas
keras. Lakukan ini sebelum lupa.

---

## Yang perlu kamu tahu soal privasinya

Ringkasan datamu — tugas, latihan, lari, makanan, keuangan — dikirim ke server
Anthropic tiap kali kamu bertanya. Yang dikirim ringkasan, bukan data mentah,
dan tidak ada nama atau alamat. Tapi tetap saja itu keluar dari HP-mu.

Kalau kamu tidak nyaman dengan itu, jangan aktifkan fitur ini — sisa app-nya
jalan normal tanpa fungsi ini.
