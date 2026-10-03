// Edge Function "foto-makanan" — menebak isi piring dan gizinya dari foto.
//
// Penyedia AI-nya Gemini (kalau GEMINI_API_KEY ada) atau Claude; lihat
// ../_shared/ai.ts. API key hanya hidup di sini sebagai secret Supabase, tidak
// pernah di APK. App mengirim satu foto (sudah diperkecil di HP) plus
// keterangan opsional; fungsi ini tidak membaca database sama sekali.
//
// Hasilnya PERKIRAAN. Porsi dari foto bisa meleset jauh — minyak, santan, dan
// gula yang larut tidak terlihat sama sekali. App selalu menampilkannya untuk
// diperiksa, tidak pernah langsung menyimpan.

import {
  bacaJson,
  isMediaType,
  json,
  MAX_IMAGE_CHARS,
  mintaAi,
  periksaAwal,
  responsGalat,
} from "../_shared/ai.ts";

const MAX_NOTE_CHARS = 300;
const MAX_HABITS = 20;

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
- Kalau ada daftar porsi yang biasa dicatat pengguna, pakai sebagai patokan
  berat untuk makanan yang sama ketika foto tidak jelas menunjukkan porsi yang
  berbeda. Foto tetap yang utama: piring yang jelas lebih penuh atau lebih
  sedikit harus ditaksir sesuai foto. Pakai juga nama yang sama persis dengan
  daftar itu kalau makanannya sama.
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

/** [SCHEMA] dalam dialek responseSchema Gemini. */
const GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          nama: { type: "STRING" },
          porsi: { type: "STRING" },
          gram: { type: "NUMBER" },
          kalori: { type: "NUMBER" },
          protein_g: { type: "NUMBER" },
          karbo_g: { type: "NUMBER" },
          lemak_g: { type: "NUMBER" },
          yakin: { type: "INTEGER" },
        },
        required: ["nama", "porsi", "gram", "kalori", "protein_g", "karbo_g", "lemak_g", "yakin"],
      },
    },
    catatan: { type: "STRING" },
  },
  required: ["items", "catatan"],
};

Deno.serve(async (req: Request) => {
  const awal = periksaAwal(req);
  if (awal) return awal;

  let image: string;
  let mediaType: string;
  let note: string;
  let habits: string[];
  try {
    const body = await req.json();
    image = String(body.image ?? "").trim();
    mediaType = String(body.media_type ?? "image/jpeg");
    note = String(body.note ?? "").trim().slice(0, MAX_NOTE_CHARS);
    habits = parseHabits(body.habits);
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

  const userText = [
    note ? `Keterangan dari pengguna: ${note}` : "Taksir isi piring ini.",
    habits.length ? `Porsi yang biasa dicatat pengguna:\n${habits.join("\n")}` : "",
  ].filter(Boolean).join("\n\n");

  const hasil = await mintaAi({
    system: SYSTEM_PROMPT,
    teks: userText,
    gambar: { data: image, mediaType },
    skema: { claude: SCHEMA, gemini: GEMINI_SCHEMA },
    label: "Foto ini",
  });
  if (!hasil.ok) return responsGalat(hasil);

  const parsed = bacaJson(hasil.teks);
  if (!parsed) return json({ error: "Jawaban AI tidak bisa dibaca. Coba lagi." }, 502);
  return json({
    items: Array.isArray(parsed.items) ? parsed.items : [],
    catatan: typeof parsed.catatan === "string" ? parsed.catatan : "",
  });
});

/**
 * Daftar porsi kebiasaan dari app jadi baris teks. Isinya dari pengguna, jadi
 * dibatasi jumlah dan panjangnya, dan angkanya dipastikan angka.
 */
function parseHabits(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const lines: string[] = [];
  for (const item of raw.slice(0, MAX_HABITS)) {
    if (typeof item !== "object" || item === null) continue;
    const { nama, gram, kali } = item as Record<string, unknown>;
    const name = String(nama ?? "").replace(/\s+/g, " ").trim().slice(0, 60);
    const grams = Number(gram);
    const times = Number(kali);
    if (!name || !Number.isFinite(grams) || grams <= 0 || grams > 5000) continue;
    lines.push(`- ${name}: ±${Math.round(grams)} g` + (Number.isFinite(times) ? ` (${Math.round(times)}×)` : ""));
  }
  return lines;
}
