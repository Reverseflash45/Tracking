package com.rafifernandito.tracking

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.NumberFormat
import java.time.LocalDate
import java.util.Locale

/**
 * Widget "Catat cepat": tiga tombol untuk catatan yang paling sering.
 *
 * Tombol air mencatat langsung lewat Dart di latar (antrean offline yang sama
 * dengan tombol "Sudah" di notifikasi), tanpa membuka app. Makan dan uang
 * membuka form-nya, karena keduanya butuh angka yang harus diketik.
 */
class CatatCepatWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val ml = mlHariIni(widgetData.getString(KUNCI_DATA, null))
        val teksAir = if (ml == null) {
            "Catat cepat"
        } else {
            "Minum hari ini: ${NumberFormat.getIntegerInstance(Locale("id", "ID")).format(ml)} ml"
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_catat)
            views.setTextViewText(R.id.air_hari_ini, teksAir)

            views.setOnClickPendingIntent(
                R.id.tombol_air,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("tracking://$HOST_AIR?ml=$ML_SEKALI"),
                ),
            )
            // Path-nya diteruskan Flutter ke go_router; ?catat=1 membuka form.
            views.setOnClickPendingIntent(
                R.id.tombol_makan,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("tracking://app/workout/nutrition?catat=1"),
                ),
            )
            views.setOnClickPendingIntent(
                R.id.tombol_uang,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("tracking://app/finance?catat=1"),
                ),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Null kalau belum pernah login (app belum mengirim data). */
    private fun mlHariIni(json: String?): Int? {
        if (json == null) return null
        return try {
            val data = JSONObject(json)
            if (!data.has("u")) return null
            // Angka kemarin tidak relevan lagi; setelah tengah malam mulai dari nol.
            if (data.optString("tanggal") == LocalDate.now().toString()) data.optInt("ml", 0) else 0
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        /** Kunci yang sama dengan kKunciCatatCepat di sisi Dart. */
        private const val KUNCI_DATA = "catat_cepat_widget"

        /** Host URI tombol air. Sama dengan kHostCatatAir di sisi Dart. */
        private const val HOST_AIR = "catat-air"

        private const val ML_SEKALI = 250
    }
}
