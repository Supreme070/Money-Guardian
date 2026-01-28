import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Notification payload from push messages
class NotificationPayload {
  final String? title;
  final String? body;
  final String? type;
  final String? subscriptionId;
  final String? alertId;
  final Map<String, String> data;

  const NotificationPayload({
    this.title,
    this.body,
    this.type,
    this.subscriptionId,
    this.alertId,
    this.data = const {},
  });

  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    return NotificationPayload(
      title: notification?.title ?? data['title'] as String?,
      body: notification?.body ?? data['body'] as String?,
      type: data['type'] as String?,
      subscriptionId: data['subscription_id'] as String?,
      alertId: data['alert_id'] as String?,
      data: data.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('Background message: ${message.messageId}');
  }
}

/// Service for handling push notifications via Firebase Cloud Messaging
@lazySingleton
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<NotificationPayload> _notificationController =
      StreamController<NotificationPayload>.broadcast();

  bool _initialized = false;
  String? _fcmToken;

  /// Stream of notification events
  Stream<NotificationPayload> get notifications => _notificationController.stream;

  /// Current FCM token (null if not initialized)
  String? get fcmToken => _fcmToken;

  /// Android notification channel for Money Guardian alerts
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'money_guardian_alerts',
    'Money Guardian Alerts',
    description: 'Notifications for subscription charges, overdraft warnings, and more',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  /// Initialize the notification service
  /// Call this after Firebase.initializeApp() in main()
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle message opened app (from background)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check if app was opened from a terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }

    if (kDebugMode) {
      debugPrint('NotificationService initialized with token: $_fcmToken');
    }
  }

  /// Request notification permission
  Future<NotificationSettings> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('Notification permission: ${settings.authorizationStatus}');
    }

    return settings;
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Get FCM token
  /// Note: APNs token is not available on iOS simulators
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token: $_fcmToken');
      }
    } catch (e) {
      // APNs token not available (e.g., on iOS simulator)
      if (kDebugMode) {
        debugPrint('FCM token not available: $e');
      }
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) {
    _fcmToken = token;
    if (kDebugMode) {
      debugPrint('FCM token refreshed: $token');
    }
    // Token will be synced via onTokenRefresh callback
  }

  /// Handle foreground message
  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message: ${message.notification?.title}');
    }

    final payload = NotificationPayload.fromRemoteMessage(message);

    // Show local notification
    _showLocalNotification(payload);

    // Emit to stream
    _notificationController.add(payload);
  }

  /// Handle message that opened the app
  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Message opened app: ${message.notification?.title}');
    }

    final payload = NotificationPayload.fromRemoteMessage(message);
    _notificationController.add(payload);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final payload = NotificationPayload(
          title: data['title'] as String?,
          body: data['body'] as String?,
          type: data['type'] as String?,
          subscriptionId: data['subscription_id'] as String?,
          alertId: data['alert_id'] as String?,
          data: (data['data'] as Map<String, dynamic>?)
                  ?.map((k, v) => MapEntry(k, v.toString())) ??
              {},
        );
        _notificationController.add(payload);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(NotificationPayload payload) async {
    const androidDetails = AndroidNotificationDetails(
      'money_guardian_alerts',
      'Money Guardian Alerts',
      channelDescription: 'Notifications for subscription charges, overdraft warnings, and more',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadJson = jsonEncode({
      'title': payload.title,
      'body': payload.body,
      'type': payload.type,
      'subscription_id': payload.subscriptionId,
      'alert_id': payload.alertId,
      'data': payload.data,
    });

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: payloadJson,
    );
  }

  /// Subscribe to a topic (e.g., "alerts", "promotions")
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    if (kDebugMode) {
      debugPrint('Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      debugPrint('Unsubscribed from topic: $topic');
    }
  }

  /// Dispose the service
  void dispose() {
    _notificationController.close();
  }
}
