import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationSimulator {
  static Timer? _timer;

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {},
    );

    final iosPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    debugPrint("NotificationSimulator initialized successfully");
  }

  //Reminder tiap 5 menit
  static Future<void> startRepeatingNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    _timer?.cancel();

    const androidDetails = AndroidNotificationDetails(
      'aormed_channel',
      'AorMed Notifications',
      channelDescription: 'Health reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Muncul sekali saat aplikasi dibuka
    await flutterLocalNotificationsPlugin.show(
      0,
      '💙 Jaga Kesehatanmu!',
      'Saatnya cek jadwal konsultasi atau chat dokter sekarang!',
      details,
    );

    // Foreground tiap 5 menit
    _timer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await flutterLocalNotificationsPlugin.show(
        0,
        '💙 Jaga Kesehatanmu!',
        'Saatnya cek jadwal konsultasi atau chat dokter sekarang!',
        details,
      );
    });

    //Background schedule
    for (int i = 1; i <= 20; i++) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        i,
        '💙 Jaga Kesehatanmu!',
        'Saatnya cek jadwal konsultasi atau chat dokter sekarang!',
        tz.TZDateTime.now(tz.local).add(Duration(minutes: 5 * i)),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    debugPrint("🕐 Reminder notifications scheduled every 5 minutes!");
  }

  /// 💳 Notifikasi Pembayaran Berhasil
  static Future<void> showPaymentSuccess() async {
    const androidDetails = AndroidNotificationDetails(
      'payment_channel',
      'Payment Notifications',
      channelDescription: 'Shows success payment notification',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,  
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      1001,
      '💙 Pembayaran Berhasil!',
      'Silakan konsultasi dengan dokter dalam waktu 15 menit.',
      details,
    );

    debugPrint("Payment success notification displayed!");
  }
}
