// Edge Function "tanya" — menjawab pertanyaan dari ringkasan data pengguna.
//
// KENAPA HARUS LEWAT SINI, TIDAK LANGSUNG DARI APP:
// API key yang ditaruh di kode Flutter ikut terbundel ke dalam APK. APK bisa
// dibongkar siapa pun dalam hitungan menit, dan key-nya bisa dipakai orang lain
// atas kuota atau tagihanmu. Key hanya hidup di sini, sebagai secret Supabase.
//
// Penyedianya Gemini atau Claude; lihat ../_shared/ai.ts. App mengirim
// pertanyaan plus RINGKASAN datanya sendiri (total dan rata-rata, bukan
// catatan mentah); fungsi ini tidak membaca database sama sekali.

import { json, mintaAi, periksaAwal, responsGalat } from "../_shared/ai.ts";

/** Batas panjang supaya satu permintaan tidak bisa membengkakkan kuota. */
const MAX_QUESTION_CHARS = 500;
const MAX_CONTEXT_CHARS = 12000;

const SYSTEM_PROMPT = `
Kamu asisten di dalam aplikasi pencatat pribadi milik seorang mahasiswa
Indonesia. Aplikasinya mencatat jadwal kuliah, tugas, latihan di gym, lari,
makanan, berat badan, dan keuangan.

Jawab HANYA berdasarkan data yang diberikan di bawah. Aturan:

- Kalau datanya tidak memuat jawabannya, katakan terus terang bahwa datanya
  tidak ada. Jangan mengarang angka. Tebakan yang terdengar meyakinkan jauh
  lebih berbahaya daripada mengaku tidak tahu.
- Jawab ringkas — dua sampai empat kalimat untuk pertanyaan biasa. Sebutkan
  angkanya, jangan cuma menyimpulkan.
- Pakai bahasa Indonesia sehari-hari, sapa dengan "kamu".
- Kalau ditanya soal kesehatan atau gizi di luar angka yang tercatat, jawab
  seadanya lalu ingatkan bahwa kamu bukan tenaga medis.
- Jangan memberi nasihat yang mengesankan kepastian dari data beberapa minggu.
  Sebutkan kalau sampelnya masih sedikit.
`.trim();

Deno.serve(async (req: Request) => {
  const awal = periksaAwal(req);
  if (awal) return awal;

  let question: string;
  let context: string;
  try {
    const body = await req.json();
    question = String(body.question ?? "").trim();
    context = String(body.context ?? "").trim();
  } catch {
    return json({ error: "Body bukan JSON yang sah." }, 400);
  }

  if (!question) return json({ error: "Pertanyaannya kosong." }, 400);
  if (question.length > MAX_QUESTION_CHARS) {
    return json({ error: "Pertanyaannya kepanjangan." }, 400);
  }
  if (context.length > MAX_CONTEXT_CHARS) {
    context = context.slice(0, MAX_CONTEXT_CHARS);
  }

  const hasil = await mintaAi({
    system: SYSTEM_PROMPT,
    teks: `Data saya:\n\n${context}\n\n---\n\nPertanyaan: ${question}`,
    label: "Pertanyaan itu",
  });
  if (!hasil.ok) return responsGalat(hasil);

  return json({ answer: hasil.teks || "Tidak ada jawaban yang dihasilkan." });
});
