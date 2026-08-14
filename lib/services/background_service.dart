import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 📶 لمراقبة حالة الواي فاي
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
        ?.createNotificationChannel(channel);

    // 2. إعداد خدمة الخلفية (جعل التغشيل التلقائي متوقفاً ليتم التحكم به حسب الواي فاي)
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // ⚡ لن تعمل تلقائياً عند الإقلاع إلا إذا وجد واي فاي
        isForegroundMode: true,
        notificationChannelId: 'p2p_call_channel',
        initialNotificationTitle: 'خدمة الاتصال المحلي تعمل',
        initialNotificationContent: 'جاري الاستماع للرسائل والمكالمات الواردة...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // 📡 3. فحص الواي فاي فور التشغيل ومراقبته باستمرار
    _setupWifiListener(service);
  }

  /// مراقبة حالة الواي فاي لتشغيل أو إيقاف الخدمة
  static void _setupWifiListener(FlutterBackgroundService service) {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      bool isWifi = results.contains(ConnectivityResult.wifi);
      bool isRunning = await service.isRunning();

      if (isWifi && !isRunning) {
        // 🟢 متصل بالواي فاي والخدمة متوقفة -> تشغيل الخدمة
        await service.startService();
      } else if (!isWifi && isRunning) {
        // 🔴 غير متصل بالواي فاي والخدمة تعمل -> إيقاف الخدمة فوراً وإخفاء الإشعار
        service.invoke('stopService');
      }
    });
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
    StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

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

    // مراقبة الواي فاي من داخل الخدمة نفسها للإغلاق الذاتي الفوري عند انقطاع الواي فاي
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.wifi)) {
        socketServer.stop();
        connectivitySubscription?.cancel();
        service.stopSelf();
      }
    });

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      socketServer.stop();
      connectivitySubscription?.cancel();
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
      fullScreenIntent: true,
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
