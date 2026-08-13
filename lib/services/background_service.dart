import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'p2p_socket_server.dart';
import 'contact_service.dart';

class BackgroundServiceHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// initialize background service and notifications
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 1. تهيئة الإشعارات المحلية
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // إنشاء قناة إشعارات عالية الأهمية
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'p2p_call_channel', // id
      'المكالمات والرسائل الواردة', // title
      description: 'إشعارات المكالمات والرسائل الواردة في الشبكة المحلية',
      importance: Importance.max,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
         shadowChannel(channel);

    // 2. إعداد خدمة الخلفية
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'p2p_call_channel',
        initialNotificationTitle: 'خدمة الاتصال المحلي تعمل',
        initialNotificationContent: 'جاري الاستماع للرسائل والمكالمات الواردة...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final P2PSocketServer socketServer = P2PSocketServer();

    // تشغيل سيرفر الستريم والاستماع بالخلفية على المنفذ 4040
    await socketServer.startServer(
      4040,
      onRequestConnection: (callerId, callerName, socket) async {
        String name = await ContactService.getContactName(callerName) ?? callerName;
        showNotification(
          id: 101,
          title: 'مكالمة واردة 📞',
          body: 'اتصال وارد من: $name',
        );
      },
      onMessageReceived: (senderIp, msg) async {
        showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'رسالة جديدة 💬',
          body: msg,
        );
      },
    );

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  /// إظهار إشعار منبثق علوي
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'p2p_call_channel',
      'المكالمات والرسائل الواردة',
      channelDescription: 'إشعارات المكالمات والرسائل الواردة في الشبكة المحلية',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      fullScreenIntent: true, // لإظهار الشاشة كاملة إن أمكن
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
    );
  }
}
