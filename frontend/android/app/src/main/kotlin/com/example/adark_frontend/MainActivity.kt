package com.example.adark_frontend

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val reportsChannel = NotificationChannel(
            "kinderlog_reports",
            "Báo cáo & Đơn xin phép",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Thông báo báo cáo hàng ngày, phản hồi và duyệt đơn xin phép"
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val attendanceChannel = NotificationChannel(
            "kinderlog_attendance",
            "Điểm danh",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Thông báo bé vắng mặt và nhắc nhở điểm danh"
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        val emergencyChannel = NotificationChannel(
            "kinderlog_emergency",
            "Cảnh báo khẩn cấp",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Cảnh báo sự cố sức khỏe khẩn cấp tại lớp"
            enableVibration(true)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannels(
            listOf(reportsChannel, attendanceChannel, emergencyChannel)
        )
    }
}
