package com.rafifernandito.tracking

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalTime
import java.time.temporal.ChronoUnit

/**
 * Widget layar utama: rutinitas berkala terdekat, lalu kegiatan berikutnya hari ini.
 *
 * App hanya mengirim data mentah (tanggal jatuh tempo, jadwal per hari), bukan
 * teks jadi. Label "Hari ini" / "Besok" dihitung di sini setiap kali widget
 * diperbarui, supaya tetap benar walau app berhari-hari tidak dibuka.
 */
class RutinitasWidget : HomeWidgetProvider() {

    private data class Baris(val judul: String, val label: String, val mendesak: Boolean)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val json = widgetData.getString(KUNCI_DATA, null)
        val baris = try {
            if (json == null) null else susunBaris(JSONObject(json))
        } catch (e: Exception) {
            null
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_rutinitas)

            val kosong = baris.isNullOrEmpty()
            views.setViewVisibility(R.id.kosong, if (kosong) View.VISIBLE else View.GONE)
            if (baris != null && baris.isEmpty()) {
                views.setTextViewText(R.id.kosong, "Tidak ada yang mendesak. Santai dulu.")
            }

            for (i in 0 until MAKS_BARIS) {
                val item = baris?.getOrNull(i)
                views.setViewVisibility(ID_BARIS[i], if (item == null) View.GONE else View.VISIBLE)
                if (item == null) continue
                views.setTextViewText(ID_JUDUL[i], item.judul)
                views.setTextViewText(ID_LABEL[i], item.label)
                views.setTextColor(
                    ID_LABEL[i],
                    context.getColor(if (item.mendesak) R.color.widget_mendesak else R.color.widget_redup),
                )
            }

            views.setOnClickPendingIntent(
                R.id.akar,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    // Path-nya diteruskan Flutter ke go_router sebagai rute awal.
                    Uri.parse("tracking://app/routine/berkala"),
                ),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun susunBaris(data: JSONObject): List<Baris> {
        val hariIni = LocalDate.now()
        val hasil = mutableListOf<Baris>()

        // Rutinitas berkala, sudah diurutkan app dari yang paling mendesak.
        val berkala = data.optJSONArray("berkala")
        if (berkala != null) {
            for (i in 0 until minOf(berkala.length(), MAKS_BERKALA)) {
                val item = berkala.getJSONObject(i)
                val tempo = LocalDate.parse(item.getString("d"))
                val sisa = ChronoUnit.DAYS.between(hariIni, tempo).toInt()
                // Yang masih jauh tidak perlu memakan tempat di layar utama.
                if (sisa > JARAK_TAMPIL_HARI) continue
                hasil.add(Baris(item.getString("t"), labelSisa(sisa), sisa <= 1))
            }
        }

        // Kegiatan berikutnya hari ini dari rutinitas mingguan (plus kelas).
        val harian = data.optJSONObject("harian")?.optJSONArray(hariIni.dayOfWeek.value.toString())
        if (harian != null) {
            val sekarang = LocalTime.now()
            for (i in 0 until harian.length()) {
                if (hasil.size >= MAKS_BARIS) break
                val item = harian.getJSONObject(i)
                val mulai = item.getString("m")
                if (LocalTime.parse(mulai).isBefore(sekarang)) continue
                hasil.add(Baris(item.getString("t"), mulai, false))
            }
        }

        return hasil
    }

    private fun labelSisa(sisa: Int): String = when {
        sisa < 0 -> "Telat ${-sisa} hari"
        sisa == 0 -> "Hari ini"
        sisa == 1 -> "Besok"
        else -> "$sisa hari lagi"
    }

    companion object {
        /** Kunci yang sama dengan `kKunciWidget` di sisi Dart. */
        private const val KUNCI_DATA = "rutinitas_widget"

        private const val MAKS_BARIS = 5
        private const val MAKS_BERKALA = 3
        private const val JARAK_TAMPIL_HARI = 7

        private val ID_BARIS = intArrayOf(R.id.baris0, R.id.baris1, R.id.baris2, R.id.baris3, R.id.baris4)
        private val ID_JUDUL = intArrayOf(R.id.judul0, R.id.judul1, R.id.judul2, R.id.judul3, R.id.judul4)
        private val ID_LABEL = intArrayOf(R.id.label0, R.id.label1, R.id.label2, R.id.label3, R.id.label4)
    }
}
