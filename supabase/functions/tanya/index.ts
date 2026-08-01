// Edge Function "tanya" — proksi ke Claude API.
//
// KENAPA HARUS LEWAT SINI, TIDAK LANGSUNG DARI APP:
// API key yang ditaruh di kode Flutter ikut terbundel ke dalam APK. APK bisa
// dibongkar siapa pun dalam hitungan menit, dan key-nya bisa dipakai orang lain
// atas tagihanmu. Key hanya hidup di sini, sebagai secret Supabase, dan tidak
// pernah dikirim ke perangkat.
//
// App mengirim pertanyaan plus ringkasan datanya sendiri; fungsi ini tidak
// membaca database sama sekali.

import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Batas panjang supaya satu permintaan tidak bisa membengkakkan tagihan. */
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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Gunakan POST." }, 405);
  }

  // Supabase memverifikasi JWT sebelum fungsi ini jalan (verify_jwt aktif secara
  // bawaan). Pemeriksaan di sini hanya jaring pengaman kalau setelan itu
  // sengaja dimatikan — tanpa ini, endpoint-nya jadi terbuka untuk umum.
  if (!req.headers.get("Authorization")) {
    return json({ error: "Butuh login." }, 401);
  }

  if (!Deno.env.get("ANTHROPIC_API_KEY")) {
    return json(
      { error: "ANTHROPIC_API_KEY belum diatur di secret Supabase." },
      500,
    );
  }

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

  try {
    const message = await anthropic.messages.create({
      model: "claude-opus-5",
      // Di Opus 5 thinking menyala secara bawaan, dan max_tokens membatasi
      // thinking DITAMBAH teks jawaban. Angka ini longgar supaya jawabannya
      // tidak terpotong di tengah; yang ditagih tetap hanya yang terpakai.
      max_tokens: 8192,
      // Pertanyaan sederhana atas ringkasan yang sudah dihitung app tidak butuh
      // penalaran dalam. Naikkan ke "medium" kalau jawabannya terasa dangkal.
      output_config: { effort: "low" },
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: `Data saya:\n\n${context}\n\n---\n\nPertanyaan: ${question}`,
        },
      ],
    });

    // Opus 5 bisa menolak permintaan lewat classifier keamanan; itu datang
    // sebagai HTTP 200 dengan stop_reason "refusal", bukan error. Membaca
    // content[0] tanpa memeriksa ini akan meledak.
    if (message.stop_reason === "refusal") {
      return json(
        { error: "Pertanyaan itu tidak bisa saya jawab." },
        200,
      );
    }

    const answer = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("\n")
      .trim();

    return json({ answer: answer || "Tidak ada jawaban yang dihasilkan." });
  } catch (error) {
    console.error("Panggilan Claude gagal:", error);

    const status = (error as { status?: number })?.status;
    if (status === 401) {
      return json({ error: "API key ditolak. Cek lagi secret-nya." }, 500);
    }
    if (status === 429) {
      return json({ error: "Terlalu banyak permintaan. Coba lagi sebentar." }, 429);
    }
    return json({ error: "Gagal menghubungi layanan AI." }, 502);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
