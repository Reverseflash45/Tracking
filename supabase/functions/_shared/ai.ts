// Jalur AI bersama untuk semua Edge Function: Gemini kalau GEMINI_API_KEY
// ada (paket gratis Google AI Studio), Claude kalau hanya ANTHROPIC_API_KEY
// yang diatur. Fungsi pemanggil cukup menyusun prompt dan membaca teks
// jawabannya; urusan model cadangan, kuota, dan pesan galat ada di sini.

import Anthropic from "npm:@anthropic-ai/sdk";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Batas ukuran foto dalam karakter base64 (~1,1 MB gambar). App sudah
 * memperkecil fotonya; batas ini cuma pengaman supaya satu permintaan tidak
 * bisa membengkakkan kuota atau tagihan.
 */
export const MAX_IMAGE_CHARS = 1_500_000;

export const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type MediaType = (typeof MEDIA_TYPES)[number];

export function isMediaType(value: string): value is MediaType {
  return (MEDIA_TYPES as readonly string[]).includes(value);
}

export interface Gambar {
  data: string;
  mediaType: MediaType;
}

/** Skema JSON jawaban, dalam dua dialek. */
export interface Skema {
  /** JSON Schema untuk structured outputs Claude (pakai additionalProperties: false). */
  claude: Record<string, unknown>;
  /** responseSchema Gemini: subset OpenAPI, tipe huruf besar, tanpa additionalProperties. */
  gemini: Record<string, unknown>;
}

export interface Permintaan {
  system: string;
  teks: string;
  gambar?: Gambar;
  /** Tanpa skema, jawabannya teks bebas. */
  skema?: Skema;
  /** Dipakai di pesan galat: "Foto ini", "Pertanyaan itu". */
  label: string;
}

export type HasilAi =
  | { ok: true; teks: string; penyedia: "gemini" | "claude" }
  | { ok: false; pesan: string; status: number };

/**
 * Model Gemini yang dicoba berurutan; keduanya ada di paket gratis Google AI
 * Studio. Model berikutnya hanya dipakai kalau yang sebelumnya penuh.
 *
 * Flash-Lite didahulukan. Diuji Oktober 2026 dengan foto KRS dan foto nasi
 * goreng: hasilnya sama dengan Flash, tapi 3–10 detik, sementara Flash sering
 * penuh (503) dan waktunya 15–60 detik.
 */
export const GEMINI_MODELS = ["gemini-flash-lite-latest", "gemini-3.8-flash"];

/** Null kalau belum ada key AI sama sekali. */
export function penyediaAktif(): "gemini" | "claude" | null {
  if (Deno.env.get("GEMINI_API_KEY")) return "gemini";
  if (Deno.env.get("ANTHROPIC_API_KEY")) return "claude";
  return null;
}

export const PESAN_TANPA_KEY =
  "Belum ada API key AI. Atur GEMINI_API_KEY atau ANTHROPIC_API_KEY di secret Supabase.";

/** Kirim permintaan ke penyedia yang aktif dan kembalikan teks jawabannya. */
export async function mintaAi(p: Permintaan): Promise<HasilAi> {
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (geminiKey) return await mintaGemini(geminiKey, p);
  if (Deno.env.get("ANTHROPIC_API_KEY")) return await mintaClaude(p);
  return { ok: false, pesan: PESAN_TANPA_KEY, status: 500 };
}

/**
 * Lewat Gemini (REST, tanpa SDK). Model berikutnya dicoba hanya kalau yang
 * sekarang penuh atau kena batas kuota — kesalahan lain (key salah, input
 * ditolak) tidak akan berbeda di model lain.
 */
async function mintaGemini(key: string, p: Permintaan): Promise<HasilAi> {
  const parts: unknown[] = [];
  if (p.gambar) {
    parts.push({ inline_data: { mime_type: p.gambar.mediaType, data: p.gambar.data } });
  }
  parts.push({ text: p.teks });

  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: p.system }] },
    contents: [{ role: "user", parts }],
    generationConfig: {
      ...(p.skema ? { responseMimeType: "application/json", responseSchema: p.skema.gemini } : {}),
      // Bawaannya "high": Flash bisa berpikir hampir semenit untuk satu
      // gambar tanpa hasil yang lebih baik untuk tugas-tugas di sini.
      thinkingConfig: { thinkingLevel: "low" },
    },
  });

  let statusTerakhir = 0;
  for (const model of GEMINI_MODELS) {
    let res: globalThis.Response;
    try {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
          body,
          signal: AbortSignal.timeout(60_000),
        },
      );
    } catch (error) {
      console.error(`Gemini ${model} tidak terjangkau:`, error);
      statusTerakhir = 504;
      continue;
    }

    if (res.status === 503 || res.status === 429 || res.status === 500) {
      console.warn(`Gemini ${model} ${res.status}, coba model berikutnya`);
      statusTerakhir = res.status;
      continue;
    }
    if (res.status === 400 || res.status === 403) {
      const detail = await res.text();
      console.error(`Gemini ${model} ${res.status}:`, detail.slice(0, 500));
      return detail.includes("API_KEY") || res.status === 403
        ? { ok: false, pesan: "API key Gemini ditolak. Cek lagi secret-nya.", status: 500 }
        : { ok: false, pesan: `${p.label} ditolak oleh layanan AI.`, status: 400 };
    }
    if (!res.ok) {
      console.error(`Gemini ${model} ${res.status}:`, (await res.text()).slice(0, 500));
      statusTerakhir = res.status;
      continue;
    }

    const data = await res.json();
    const kandidat = data?.candidates?.[0];
    if (!kandidat || data?.promptFeedback?.blockReason || kandidat.finishReason === "SAFETY") {
      return { ok: false, pesan: `${p.label} tidak bisa diproses AI.`, status: 422 };
    }
    if (kandidat.finishReason === "MAX_TOKENS") {
      return { ok: false, pesan: "Jawabannya terpotong. Coba lagi.", status: 502 };
    }

    const teks = (kandidat.content?.parts ?? [])
      .filter((x: { text?: string; thought?: boolean }) => typeof x.text === "string" && !x.thought)
      .map((x: { text: string }) => x.text)
      .join("")
      .trim();
    return { ok: true, teks, penyedia: "gemini" };
  }

  return statusTerakhir === 429
    ? { ok: false, pesan: "Kuota gratis Gemini hari ini habis. Coba lagi besok.", status: 429 }
    : { ok: false, pesan: "Layanan AI sedang penuh. Coba lagi sebentar.", status: 503 };
}

async function mintaClaude(p: Permintaan): Promise<HasilAi> {
  const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  if (p.gambar) {
    content.push({
      type: "image",
      source: { type: "base64", media_type: p.gambar.mediaType, data: p.gambar.data },
    });
  }
  content.push({ type: "text", text: p.teks });

  try {
    const message = await anthropic.beta.messages.create({
      model: "claude-opus-5-5",
      // Di Opus 5.5 thinking selalu menyala, dan max_tokens membatasi
      // thinking DITAMBAH jawaban. Angka ini longgar supaya jawabannya tidak
      // terpotong; yang ditagih tetap hanya yang terpakai.
      max_tokens: 16000,
      // Tugas-tugas di sini (menaksir piring, menyalin tabel, menjawab dari
      // ringkasan) tidak butuh penalaran panjang, dan tiap token ditagih.
      output_config: p.skema
        ? { effort: "low", format: { type: "json_schema", schema: p.skema.claude } }
        : { effort: "low" },
      // Kalau classifier keamanan menolak, permintaan yang sama diulang di
      // model cadangan pilihan Anthropic, bukan langsung gagal.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: p.system,
      messages: [{ role: "user", content }],
    });

    if (message.stop_reason === "refusal") {
      return { ok: false, pesan: `${p.label} tidak bisa diproses AI.`, status: 422 };
    }
    if (message.stop_reason === "max_tokens") {
      return { ok: false, pesan: "Jawabannya terpotong. Coba lagi.", status: 502 };
    }

    const teks = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("\n")
      .trim();
    return { ok: true, teks, penyedia: "claude" };
  } catch (error) {
    console.error("Panggilan Claude gagal:", error);
    if (error instanceof Anthropic.AuthenticationError) {
      return { ok: false, pesan: "API key ditolak. Cek lagi secret-nya.", status: 500 };
    }
    if (error instanceof Anthropic.RateLimitError) {
      return { ok: false, pesan: "Terlalu banyak permintaan. Coba lagi sebentar.", status: 429 };
    }
    if (error instanceof Anthropic.BadRequestError) {
      return { ok: false, pesan: `${p.label} ditolak oleh layanan AI.`, status: 400 };
    }
    return { ok: false, pesan: "Gagal menghubungi layanan AI.", status: 502 };
  }
}

/** Baca JSON dari jawaban AI; null kalau bukan JSON yang sah. */
export function bacaJson(teks: string): Record<string, unknown> | null {
  try {
    const hasil = JSON.parse(teks);
    return typeof hasil === "object" && hasil !== null && !Array.isArray(hasil) ? hasil : null;
  } catch {
    return null;
  }
}

/**
 * Pemeriksaan bersama di awal tiap fungsi: CORS preflight, metode, dan login.
 * Null berarti lanjut.
 */
export function periksaAwal(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Gunakan POST." }, 405);
  // Supabase memverifikasi JWT sebelum fungsi jalan (verify_jwt bawaan). Ini
  // jaring pengaman kalau setelan itu sengaja dimatikan — tanpa ini endpoint
  // jadi terbuka untuk umum dan kuotanya bisa dihabiskan orang lain.
  if (!req.headers.get("Authorization")) return json({ error: "Butuh login." }, 401);
  if (!penyediaAktif()) return json({ error: PESAN_TANPA_KEY }, 500);
  return null;
}

/**
 * Status HTTP yang dikirim ke app untuk galat AI. Penolakan konten dikirim
 * sebagai 200 + error, seperti sebelumnya, supaya app menampilkannya sebagai
 * pesan biasa, bukan kegagalan server.
 */
export function responsGalat(h: { pesan: string; status: number }): Response {
  return json({ error: h.pesan }, h.status === 422 ? 200 : h.status);
}
