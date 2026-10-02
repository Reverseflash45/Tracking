// Edge Function "foto-makanan" — menebak isi piring dan gizinya dari foto.
//
// Sama seperti "tanya": API key hanya hidup di sini sebagai secret Supabase,
// tidak pernah di APK. App mengirim satu foto (sudah diperkecil di HP) plus
// keterangan opsional; fungsi ini tidak membaca database sama sekali.
//
// Hasilnya PERKIRAAN. Porsi dari foto bisa meleset jauh — minyak, santan, dan
// gula yang larut tidak terlihat sama sekali. App selalu menampilkannya untuk
// diperiksa, tidak pernah langsung menyimpan.

import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Batas ukuran foto dalam karakter base64 (~1,1 MB gambar). App sudah
 * memperkecilnya ke sisi terpanjang 1024 px, biasanya 150–300 KB; batas ini
 * cuma pengaman supaya satu permintaan tidak bisa membengkakkan tagihan.
 */
const MAX_IMAGE_CHARS = 1_500_000;
const MAX_NOTE_CHARS = 300;
const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
type MediaType = (typeof MEDIA_TYPES)[number];

function isMediaType(value: string): value is MediaType {
  return (MEDIA_TYPES as readonly string[]).includes(value);
}

const SYSTEM_PROMPT = `
Kamu menaksir isi dan kandungan gizi makanan dari foto untuk aplikasi pencatat
makan milik seorang mahasiswa Indonesia.

Cara kerja:
- Pecah piring menjadi komponen yang dicatat terpisah: nasi, lauk, sayur,
  sambal, kerupuk, minuman. Satu komponen satu item.
- Pakai nama makanan Indonesia sehari-hari ("Nasi putih", "Ayam goreng paha",
  "Sayur lodeh", "Es teh manis").
- Taksir berat tiap komponen dalam gram dari ukuran relatifnya terhadap
  piring, sendok, tangan, atau benda lain di foto. Pakai porsi warung atau
  rumahan Indonesia sebagai patokan kalau tidak ada pembanding.
- Hitung kalori, protein, karbohidrat, dan lemak untuk berat itu — bukan per
  100 gram.
- Masukkan yang tidak terlihat tapi hampir pasti ada: minyak gorengan, santan,
  gula di minuman manis. Sebutkan di "porsi" kalau kamu menambahkannya.
- "yakin" 0–100: seberapa yakin kamu soal jenis DAN beratnya. Komponen yang
  tertutup, terpotong, atau ambigu harus rendah. Jangan semua diberi angka
  tinggi.
- Kalau ada keterangan dari pengguna, keterangan itu mengalahkan tebakanmu.
- Kalau fotonya bukan makanan atau terlalu buram, kembalikan "items" kosong dan
  jelaskan di "catatan".

"catatan": satu atau dua kalimat bahasa Indonesia sehari-hari, sapa dengan
"kamu" — hal yang paling mungkin membuat taksiran meleset dan perlu kamu
periksa. Jangan memberi nasihat diet.
`.trim();

/** Bentuk jawaban yang dipaksakan lewat structured outputs. */
const SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          nama: { type: "string" },
          porsi: { type: "string" },
          gram: { type: "number" },
          kalori: { type: "number" },
          protein_g: { type: "number" },
          karbo_g: { type: "number" },
          lemak_g: { type: "number" },
          yakin: { type: "integer" },
        },
        required: ["nama", "porsi", "gram", "kalori", "protein_g", "karbo_g", "lemak_g", "yakin"],
        additionalProperties: false,
      },
    },
    catatan: { type: "string" },
  },
  required: ["items", "catatan"],
  additionalProperties: false,
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Gunakan POST." }, 405);
  }

  // Supabase memverifikasi JWT sebelum fungsi ini jalan. Ini jaring pengaman
  // kalau setelan itu sengaja dimatikan.
  if (!req.headers.get("Authorization")) {
    return json({ error: "Butuh login." }, 401);
  }
  if (!Deno.env.get("ANTHROPIC_API_KEY")) {
    return json({ error: "ANTHROPIC_API_KEY belum diatur di secret Supabase." }, 500);
  }

  let image: string;
  let mediaType: string;
  let note: string;
  try {
    const body = await req.json();
    image = String(body.image ?? "").trim();
    mediaType = String(body.media_type ?? "image/jpeg");
    note = String(body.note ?? "").trim().slice(0, MAX_NOTE_CHARS);
  } catch {
    return json({ error: "Body bukan JSON yang sah." }, 400);
  }

  if (!image) return json({ error: "Fotonya kosong." }, 400);
  if (image.length > MAX_IMAGE_CHARS) {
    return json({ error: "Fotonya terlalu besar." }, 413);
  }
  if (!isMediaType(mediaType)) {
    return json({ error: "Format foto tidak didukung." }, 400);
  }
  const jenis: MediaType = mediaType;

  try {
    const message = await anthropic.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      // Menaksir porsi dari satu foto tidak butuh penalaran panjang, dan tiap
      // token keluaran ditagih. Naikkan ke "medium" kalau taksirannya terasa
      // ceroboh.
      output_config: {
        effort: "low",
        format: { type: "json_schema", schema: SCHEMA },
      },
      // Kalau classifier keamanan menolak (jarang, tapi bisa terjadi pada
      // foto apa pun), permintaan yang sama diulang di model cadangan yang
      // dipilih Anthropic, bukan langsung gagal.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: jenis, data: image },
            },
            {
              type: "text",
              text: note
                ? `Keterangan dari pengguna: ${note}`
                : "Taksir isi piring ini.",
            },
          ],
        },
      ],
    });

    if (message.stop_reason === "refusal") {
      return json({ error: "Foto ini tidak bisa dianalisis. Isi manual saja." }, 200);
    }
    if (message.stop_reason === "max_tokens") {
      return json({ error: "Jawabannya terpotong. Coba lagi." }, 502);
    }

    const text = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("")
      .trim();

    const parsed = JSON.parse(text);
    return json({
      items: Array.isArray(parsed.items) ? parsed.items : [],
      catatan: typeof parsed.catatan === "string" ? parsed.catatan : "",
    });
  } catch (error) {
    console.error("Analisis foto gagal:", error);

    if (error instanceof SyntaxError) {
      return json({ error: "Jawaban AI tidak bisa dibaca. Coba lagi." }, 502);
    }
    if (error instanceof Anthropic.AuthenticationError) {
      return json({ error: "API key ditolak. Cek lagi secret-nya." }, 500);
    }
    if (error instanceof Anthropic.RateLimitError) {
      return json({ error: "Terlalu banyak permintaan. Coba lagi sebentar." }, 429);
    }
    if (error instanceof Anthropic.BadRequestError) {
      return json({ error: "Foto ditolak oleh layanan AI. Coba foto lain." }, 400);
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
