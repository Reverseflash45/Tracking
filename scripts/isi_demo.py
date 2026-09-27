"""Mengisi akun demo dengan data rekaan, supaya aplikasi bisa dicoba dan
ditangkap layarnya tanpa data pribadi siapa pun.

    python scripts/isi_demo.py                      # akun demo bawaan
    python scripts/isi_demo.py email@x.id sandi     # akun lain

Membaca SUPABASE_URL dan SUPABASE_ANON_KEY dari .env. Semua penulisan lewat
REST dengan token akun itu sendiri, jadi Row Level Security tetap berlaku:
skrip ini tidak bisa menyentuh data akun lain. Data lama akun tersebut di
tabel-tabel yang diisi akan dihapus lebih dulu, sehingga aman diulang.
"""

from __future__ import annotations

import random
import sys
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

import httpx

EMAIL, SANDI = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ("demo@raffstw.my.id", "TrackingDemo2026")
WIB = timezone(timedelta(hours=7))
HARI_INI = date.today()
acak = random.Random(7)


def baca_env() -> dict[str, str]:
    env = {}
    for baris in (Path(__file__).resolve().parent.parent / ".env").read_text(encoding="utf-8").splitlines():
        if "=" in baris and not baris.lstrip().startswith("#"):
            k, v = baris.split("=", 1)
            env[k.strip()] = v.strip()
    return env


def main() -> None:
    env = baca_env()
    url, anon = env["SUPABASE_URL"], env["SUPABASE_ANON_KEY"]
    r = httpx.post(f"{url}/auth/v1/token", params={"grant_type": "password"},
                   headers={"apikey": anon}, json={"email": EMAIL, "password": SANDI}, timeout=30)
    r.raise_for_status()
    token, uid = r.json()["access_token"], r.json()["user"]["id"]
    rest = httpx.Client(base_url=f"{url}/rest/v1", timeout=30, headers={
        "apikey": anon, "Authorization": f"Bearer {token}",
        "Content-Type": "application/json", "Prefer": "return=representation",
    })

    def kosongkan(tabel: str) -> None:
        rest.delete(f"/{tabel}", params={"user_id": f"eq.{uid}"}).raise_for_status()

    def isi(tabel: str, baris: list[dict]) -> list[dict]:
        if not baris:
            return []
        # PostgREST menolak kiriman massal yang kolomnya tidak seragam
        kolom = {k for b in baris for k in b}
        seragam = [{"user_id": uid, **{k: b.get(k) for k in kolom}} for b in baris]
        r = rest.post(f"/{tabel}", json=seragam)
        if r.status_code >= 400:
            raise SystemExit(f"{tabel}: {r.status_code} {r.text}")
        print(f"  {tabel:<20} {len(baris):>3} baris")
        return r.json()

    # urutan hapus: anak dulu, lalu induk
    for t in ["workout_exercises", "workout_sessions", "class_schedules", "tasks", "courses", "transactions",
              "sleep_logs", "weight_logs", "goals", "runs", "food_logs", "water_logs", "notes", "wishlist_items", "media_items"]:
        kosongkan(t)
    for t in ["finance_settings", "body_profiles"]:
        kosongkan(t)

    print(f"Mengisi akun {EMAIL}")

    # ---------- kuliah ----------
    matkul = isi("courses", [
        {"name": "Pemrograman Mobile", "lecturer": "Dr. Sari Wulandari"},
        {"name": "Basis Data Lanjut", "lecturer": "Ahmad Fauzi, M.Kom."},
        {"name": "Pembelajaran Mesin", "lecturer": "Dr. Budi Santoso"},
        {"name": "Rekayasa Perangkat Lunak", "lecturer": "Rina Kusuma, M.T."},
        {"name": "Statistika Terapan", "lecturer": "Dewi Anggraini, M.Si."},
    ])
    id_mk = {m["name"]: m["id"] for m in matkul}
    jadwal = [
        ("Pemrograman Mobile", 1, "08:00", "10:30", "Lab 3.2"),
        ("Statistika Terapan", 1, "13:00", "14:40", "R 2.04"),
        ("Basis Data Lanjut", 2, "10:00", "12:30", "Lab 2.1"),
        ("Pembelajaran Mesin", 3, "08:00", "10:30", "R 3.07"),
        ("Rekayasa Perangkat Lunak", 4, "09:00", "11:30", "R 2.11"),
        ("Pemrograman Mobile", 4, "13:00", "14:40", "Lab 3.2"),
        ("Basis Data Lanjut", 5, "08:00", "09:40", "R 1.05"),
    ]
    isi("class_schedules", [
        {"course_id": id_mk[n], "day_of_week": h, "start_time": a, "end_time": b, "room": r}
        for n, h, a, b, r in jadwal
    ])

    # Tanpa zona waktu, sama seperti yang dikirim app (DateTime lokal
    # .toIso8601String()): app menyimpan dan membaca tenggat sebagai jam
    # dinding. Mengirim "+07:00" di sini membuat tampilannya bergeser 7 jam.
    def tenggat(hari: int, jam: int = 23) -> str:
        return datetime.combine(HARI_INI + timedelta(days=hari), time(jam, 59)).isoformat()

    tugas = [
        ("Laporan praktikum Flutter state management", "Pemrograman Mobile", 1, "high", "in_progress"),
        ("Normalisasi skema toko daring sampai 3NF", "Basis Data Lanjut", 2, "high", "todo"),
        ("Kuis regresi logistik", "Pembelajaran Mesin", 3, "medium", "todo"),
        ("Dokumen SRS kelompok, bab 3", "Rekayasa Perangkat Lunak", 6, "medium", "todo"),
        ("Latihan soal uji hipotesis", "Statistika Terapan", 9, "low", "todo"),
        ("Presentasi proposal proyek akhir", "Pemrograman Mobile", 13, "high", "todo"),
        ("Resume jurnal decision tree", "Pembelajaran Mesin", -2, "medium", "done"),
        ("ERD sistem perpustakaan", "Basis Data Lanjut", -4, "medium", "done"),
    ]
    isi("tasks", [
        {"title": j, "course_id": id_mk[m], "deadline": tenggat(h), "priority": p, "status": s,
         **({"completed_at": tenggat(h - 1, 20)} if s == "done" else {})}
        for j, m, h, p, s in tugas
    ])

    # ---------- workout ----------
    program = [
        [("Bench Press", 55, 4, 8), ("Overhead Press", 30, 3, 10), ("Tricep Dips", None, 3, 12)],
        [("Squat", 70, 4, 6), ("Romanian Deadlift", 60, 3, 10), ("Plank", None, 3, None)],
        [("Pull Up", None, 4, 8), ("Barbell Row", 50, 4, 10), ("Bicep Curl", 12, 3, 12)],
    ]
    sesi_tanggal = [HARI_INI - timedelta(days=d) for d in (1, 3, 5, 8, 10, 12, 15, 17, 19, 22, 24)]
    sesi = isi("workout_sessions", [{"session_date": d.isoformat()} for d in sesi_tanggal])
    latihan = []
    for i, s in enumerate(sesi):
        naik = (len(sesi) - i) * 1.25  # sesi terbaru sedikit lebih berat: ada progres
        for nama, berat, set_, rep in program[i % 3]:
            jenis = "isometrik" if nama == "Plank" else ("bodyweight" if berat is None else "beban")
            latihan.append({
                "session_id": s["id"], "exercise_name": nama, "exercise_type": jenis, "sets": set_,
                "reps": rep, "weight_kg": round(berat + naik, 1) if berat else None,
                **({"duration_seconds": 60} if jenis == "isometrik" else {}),
            })
    isi("workout_exercises", latihan)

    # ---------- keuangan ----------
    isi("finance_settings", [{"monthly_budget": 2_000_000, "payday_day": 1}])
    transaksi = [{"occurred_on": HARI_INI.replace(day=1).isoformat(), "kind": "pemasukan",
                  "category": "kiriman", "amount": 2_500_000, "note": "Kiriman bulanan"}]
    # nilai kategori = TxCategory.dbValue di lib/features/finance/domain/transaction.dart
    pola = [("makan", 12_000, 35_000, ["Warung Bu Tini", "Kantin Fakultas", "Geprek Bensu"]),
            ("transport", 8_000, 25_000, ["Gojek", "Grab"]),
            ("hiburan", 15_000, 45_000, ["Kopi Kenangan", "Janji Jiwa", "CGV"]),
            ("belanja", 25_000, 90_000, ["Indomaret", "Alfamart"])]
    for d in range((HARI_INI - HARI_INI.replace(day=1)).days + 1):
        tgl = HARI_INI.replace(day=1) + timedelta(days=d)
        for kategori, lo, hi, tempat in acak.sample(pola, k=acak.randint(1, 3)):
            transaksi.append({"occurred_on": tgl.isoformat(), "kind": "pengeluaran", "category": kategori,
                              "amount": round(acak.randint(lo, hi), -3), "merchant": acak.choice(tempat)})
    transaksi.append({"occurred_on": HARI_INI.replace(day=3).isoformat(), "kind": "pengeluaran",
                      "category": "pulsa", "amount": 100_000, "merchant": "Telkomsel"})
    transaksi.append({"occurred_on": HARI_INI.replace(day=5).isoformat(), "kind": "pengeluaran",
                      "category": "lainnya", "amount": 850_000, "note": "Kos", "merchant": "Kos Griya Asri"})
    isi("transactions", transaksi)

    # ---------- tubuh, tidur, target ----------
    isi("body_profiles", [{"height_cm": 172, "birth_date": "2005-03-14", "gender": "pria",
                           "activity_level": "sedang", "goal": "bulking", "target_weight_kg": 68,
                           "target_date": (HARI_INI + timedelta(days=90)).isoformat()}])
    isi("weight_logs", [{"logged_on": (HARI_INI - timedelta(days=7 * w)).isoformat(),
                         "weight_kg": round(63.2 + (8 - w) * 0.35 + acak.uniform(-0.2, 0.2), 1)} for w in range(9)])
    isi("sleep_logs", [{"logged_on": (HARI_INI - timedelta(days=d)).isoformat(),
                        "hours": round(acak.uniform(5.5, 8.2) * 2) / 2, "quality": acak.randint(2, 5)} for d in range(14)])
    # ---------- nutrisi: 6 hari terakhir penuh, hari ini sarapan + makan siang ----------
    menu = {
        "sarapan": [("Nasi uduk + telur", 520, 17, 70, 18), ("Roti gandum selai kacang", 380, 14, 45, 15),
                    ("Oatmeal pisang", 350, 11, 62, 7)],
        "makan_siang": [("Nasi ayam geprek", 780, 38, 85, 30), ("Gado-gado + lontong", 610, 22, 70, 26),
                        ("Nasi padang rendang", 850, 35, 90, 38)],
        "makan_malam": [("Mie ayam bakso", 640, 28, 80, 20), ("Nasi pecel lele", 720, 34, 75, 30),
                        ("Soto ayam + nasi", 560, 30, 65, 17)],
        "camilan": [("Susu protein", 180, 24, 8, 4), ("Pisang 2 buah", 210, 2, 54, 1)],
    }
    makan = []
    for d in range(7):
        hari = (HARI_INI - timedelta(days=d)).isoformat()
        waktu = ["sarapan", "makan_siang"] if d == 0 else ["sarapan", "makan_siang", "makan_malam", "camilan"]
        for m in waktu:
            nama, kkal, p, k, l = acak.choice(menu[m])
            makan.append({"logged_on": hari, "name": nama, "meal": m, "calories": kkal,
                          "protein_g": p, "carbs_g": k, "fat_g": l})
    isi("food_logs", makan)
    isi("water_logs", [{"logged_on": (HARI_INI - timedelta(days=d)).isoformat(), "ml": ml}
                       for d in range(7) for ml in ([250] * (4 if d == 0 else acak.randint(6, 10)))])
    # ---------- catatan, wishlist, watchlist ----------
    isi("notes", [
        {"title": "Ide tugas akhir", "pinned": True,
         "body": "1. Deteksi hama padi dari foto daun (CNN)\n2. Aplikasi antre puskesmas\n3. Analisis sentimen ulasan KRL"},
        {"title": "Wifi lab 3.2", "pinned": False, "body": "SSID: LAB-TI-32\nMinta password ke asisten tiap awal semester"},
        {"title": "Belanja bulanan", "pinned": False, "body": "Beras 5 kg, telur 1 kg, sabun, pasta gigi, kopi sachet"},
    ])
    isi("wishlist_items", [
        {"name": "Keyboard mekanikal 75%", "price": 650_000, "saved": 420_000, "category": "belanja", "priority": "tinggi",
         "target_date": (HARI_INI + timedelta(days=45)).isoformat()},
        {"name": "Sepatu lari", "price": 900_000, "saved": 150_000, "category": "belanja", "priority": "sedang"},
        {"name": "Kursus Flutter lanjutan", "price": 350_000, "saved": 350_000, "category": "kuliah", "priority": "tinggi"},
    ])
    isi("media_items", [
        {"title": "Frieren: Beyond Journey's End", "kind": "series", "origin": "anime", "status": "jalan", "progress": 18, "total": 28, "year": 2023},
        {"title": "Laskar Pelangi", "kind": "buku", "origin": "indonesia", "status": "selesai", "progress": 529, "total": 529, "rating": 5,
         "finished_on": (HARI_INI - timedelta(days=12)).isoformat()},
        {"title": "Dune: Part Two", "kind": "film", "origin": "hollywood", "status": "rencana", "progress": 0, "year": 2024},
        {"title": "Clean Code", "kind": "buku", "origin": "hollywood", "status": "jalan", "progress": 140, "total": 431},
    ])
    isi("goals", [
        {"title": "Latihan 12 kali bulan ini", "metric": "sesiLatihan", "target_value": 12, "period": "bulanan"},
        {"title": "Pengeluaran di bawah 2 juta", "metric": "batasPengeluaran", "target_value": 2_000_000, "period": "bulanan"},
        {"title": "Tidur cukup 5 malam seminggu", "metric": "malamTidurCukup", "target_value": 5, "period": "mingguan"},
        {"title": "Lari 15 km bulan ini", "metric": "jarakLari", "target_value": 15, "period": "bulanan"},
    ])
    isi("runs", [{"started_at": datetime.combine(HARI_INI - timedelta(days=d), time(6, 10)).isoformat(),
                  "duration_seconds": s, "distance_meters": m}
                 for d, s, m in [(2, 1560, 4100), (6, 1820, 4800), (13, 1500, 3900), (20, 1410, 3600)]])
    print("Selesai.")


if __name__ == "__main__":
    main()
