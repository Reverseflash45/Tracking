// Edge Function "baca-krs" — menyalin jadwal kuliah dari foto atau screenshot
// KRS.
//
// Pembaca KRS di app (OCR on-device + penebak pola) tetap ada sebagai
// cadangan saat offline atau kuota AI habis. Bedanya, AI melihat tabelnya
// sebagai tabel: kolom yang terpecah dua baris, sel yang digabung, dan format
// tiap kampus yang berbeda tidak perlu diakali satu per satu.
//
// Hasilnya tetap ditampilkan untuk diperiksa; app tidak pernah langsung
// menyimpan. Fungsi ini tidak membaca database.

import {
  bacaJson,
  isMediaType,
  json,
  MAX_IMAGE_CHARS,
  mintaAi,
  periksaAwal,
  responsGalat,
} from "../_shared/ai.ts";

/** Satu KRS jarang lebih dari 12 mata kuliah; ini pengaman dari jawaban liar. */
const MAX_BARIS = 40;

const SYSTEM_PROMPT = `
Kamu menyalin jadwal kuliah dari foto atau screenshot KRS (Kartu Rencana
Studi) kampus Indonesia ke data terstruktur.

Aturan:
- Satu baris "jadwal" untuk tiap pertemuan mingguan. Mata kuliah yang bertemu
  dua kali seminggu (mis. teori Senin, praktikum Kamis) jadi dua baris.
- Salin apa adanya dari gambar. Jangan menebak atau melengkapi hari, jam, atau
  ruangan yang tidak terlihat. Kalau hari ATAU jam sebuah mata kuliah tidak
  terbaca, lewati baris itu dan sebutkan nama mata kuliahnya di "catatan".
- "nama": nama mata kuliah saja, tanpa kode, SKS, atau kelas. Rapikan huruf
  kapital menjadi gaya judul ("Basis Data", bukan "BASIS DATA"), tapi
  pertahankan singkatan dan angka romawi ("PKN", "Agama Islam II").
- "kode": kode mata kuliah persis seperti tertulis, huruf besar (mis.
  "SIC204"). Kosongkan kalau tidak ada.
- "kelas": kode kelas/rombel (mis. "TI-B2", "A"). Kosongkan kalau tidak ada.
- "sks": angka SKS; 0 kalau tidak tertulis.
- "hari": 1 = Senin, 2 = Selasa, 3 = Rabu, 4 = Kamis, 5 = Jumat, 6 = Sabtu,
  7 = Minggu.
- "mulai" dan "selesai": format 24 jam "HH:MM" (mis. "07:30", "13:00"). Kalau
  KRS menulis rentang seperti "07.30 s/d 09.10", ubah titiknya jadi titik dua.
- "ruang": nama atau kode ruangan persis seperti tertulis. Kosongkan kalau
  tidak ada.
- "dosen": nama dosen pengampu kalau tertulis, tanpa mengubah gelar.
  Kosongkan kalau tidak ada.
- Abaikan kolom status persetujuan, tombol aksi, total SKS, dan tanda tangan.
- Kalau gambarnya bukan KRS atau jadwal kuliah, atau terlalu buram, kembalikan
  "jadwal" kosong dan jelaskan di "catatan".

"catatan": satu atau dua kalimat bahasa Indonesia sehari-hari, sapa dengan
"kamu" — bagian yang tidak terbaca atau perlu diperiksa. Kosongkan kalau
semuanya jelas.
`.trim();

const SCHEMA = {
  type: "object",
  properties: {
    jadwal: {
      type: "array",
      items: {
        type: "object",
        properties: {
          nama: { type: "string" },
          kode: { type: "string" },
          kelas: { type: "string" },
          sks: { type: "integer" },
          hari: { type: "integer" },
          mulai: { type: "string" },
          selesai: { type: "string" },
          ruang: { type: "string" },
          dosen: { type: "string" },
        },
        required: ["nama", "kode", "kelas", "sks", "hari", "mulai", "selesai", "ruang", "dosen"],
        additionalProperties: false,
      },
    },
    catatan: { type: "string" },
  },
  required: ["jadwal", "catatan"],
  additionalProperties: false,
};

/** [SCHEMA] dalam dialek responseSchema Gemini. */
const GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    jadwal: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          nama: { type: "STRING" },
          kode: { type: "STRING" },
          kelas: { type: "STRING" },
          sks: { type: "INTEGER" },
          hari: { type: "INTEGER" },
          mulai: { type: "STRING" },
          selesai: { type: "STRING" },
          ruang: { type: "STRING" },
          dosen: { type: "STRING" },
        },
        required: ["nama", "kode", "kelas", "sks", "hari", "mulai", "selesai", "ruang", "dosen"],
      },
    },
    catatan: { type: "STRING" },
  },
  required: ["jadwal", "catatan"],
};

Deno.serve(async (req: Request) => {
  const awal = periksaAwal(req);
  if (awal) return awal;

  let image: string;
  let mediaType: string;
  try {
    const body = await req.json();
    image = String(body.image ?? "").trim();
    mediaType = String(body.media_type ?? "image/jpeg");
  } catch {
    return json({ error: "Body bukan JSON yang sah." }, 400);
  }

  if (!image) return json({ error: "Gambarnya kosong." }, 400);
  if (image.length > MAX_IMAGE_CHARS) {
    return json({ error: "Gambarnya terlalu besar." }, 413);
  }
  if (!isMediaType(mediaType)) {
    return json({ error: "Format gambar tidak didukung." }, 400);
  }

  const hasil = await mintaAi({
    system: SYSTEM_PROMPT,
    teks: "Salin jadwal kuliah dari KRS ini.",
    gambar: { data: image, mediaType },
    skema: { claude: SCHEMA, gemini: GEMINI_SCHEMA },
    label: "Gambar ini",
  });
  if (!hasil.ok) return responsGalat(hasil);

  const parsed = bacaJson(hasil.teks);
  if (!parsed) return json({ error: "Jawaban AI tidak bisa dibaca. Coba lagi." }, 502);

  const mentah = Array.isArray(parsed.jadwal) ? parsed.jadwal : [];
  const jadwal = mentah.slice(0, MAX_BARIS).map(rapikan).filter((x) => x !== null);
  const dibuang = Math.min(mentah.length, MAX_BARIS) - jadwal.length;

  let catatan = typeof parsed.catatan === "string" ? parsed.catatan.trim() : "";
  if (dibuang > 0) {
    catatan = [catatan, `${dibuang} baris dilewati karena hari atau jamnya tidak masuk akal.`]
      .filter(Boolean)
      .join(" ");
  }
  return json({ jadwal, catatan });
});

/**
 * Pastikan satu baris jawaban AI benar-benar bisa disimpan: hari 1–7, jam
 * "HH:MM" yang sah, dan jam selesai setelah jam mulai. Model kadang menulis
 * "7.30" atau "07:30:00"; bentuk itu dinormalkan, bukan dibuang.
 */
function rapikan(raw: unknown) {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;

  const teks = (v: unknown, maks: number) => String(v ?? "").replace(/\s+/g, " ").trim().slice(0, maks);
  const nama = teks(r.nama, 120);
  const hari = Number(r.hari);
  const mulai = jam(r.mulai);
  const selesai = jam(r.selesai);

  if (nama.length < 2 || !Number.isInteger(hari) || hari < 1 || hari > 7) return null;
  if (!mulai || !selesai || selesai <= mulai) return null;

  const sks = Number(r.sks);
  return {
    nama,
    kode: teks(r.kode, 20).toUpperCase(),
    kelas: teks(r.kelas, 20),
    sks: Number.isInteger(sks) && sks > 0 && sks <= 12 ? sks : 0,
    hari,
    mulai,
    selesai,
    ruang: teks(r.ruang, 60),
    dosen: teks(r.dosen, 120),
  };
}

/** "7.30", "07:30", "07:30:00" → "07:30"; null kalau bukan jam yang sah. */
function jam(v: unknown): string | null {
  const cocok = String(v ?? "").trim().match(/^(\d{1,2})[.:](\d{2})(?::\d{2})?$/);
  if (!cocok) return null;
  const h = Number(cocok[1]);
  const m = Number(cocok[2]);
  if (h > 23 || m > 59) return null;
  return `${String(h).padStart(2, "0")}:${cocok[2]}`;
}
