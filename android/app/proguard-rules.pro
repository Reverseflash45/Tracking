# Aturan R8 untuk build rilis.

# Plugin google_mlkit_text_recognition merujuk pengenal aksara Mandarin,
# Devanagari, Jepang, dan Korea, tapi hanya dependensi Latin yang ditarik —
# itu memang yang dipakai app ini, dan menambahkan sisanya berarti menyeret
# empat model bahasa ke dalam APK tanpa alasan.
#
# Kelas-kelas itu hanya disentuh kalau script selain latin diminta saat runtime,
# yang tidak pernah terjadi di sini, jadi aman diabaikan.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
