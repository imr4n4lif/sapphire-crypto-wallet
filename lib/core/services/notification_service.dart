import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Initialize notifications
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (initialized == true) {
      _initialized = true;
      await _createNotificationChannel();
      print('✅ Notifications initialized successfully');
    } else {
      print('❌ Failed to initialize notifications');
    }
  }

  // Create notification channel for Android 8.0+
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'transaction_channel',
      'Transactions',
      description: 'Notifications for wallet transactions',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  // Show transaction received notification
  Future<void> showTransactionReceived({
    required String coinSymbol,
    required double amount,
    required String txHash,
  }) async {
    if (!_initialized) {
      print('⚠️ Notifications not initialized');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for incoming transactions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        txHash.hashCode.abs() % 2147483647, // Ensure valid notification ID
        '✅ Received $coinSymbol',
        'You received $amount $coinSymbol',
        details,
        payload: txHash,
      );
      print('✅ Notification shown: Received $amount $coinSymbol');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Show transaction sent notification
  Future<void> showTransactionSent({
    required String coinSymbol,
    required double amount,
    required String txHash,
  }) async {
    if (!_initialized) {
      print('⚠️ Notifications not initialized');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for outgoing transactions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        txHash.hashCode.abs() % 2147483647,
        '📤 Sent $coinSymbol',
        'You sent $amount $coinSymbol',
        details,
        payload: txHash,
      );
      print('✅ Notification shown: Sent $amount $coinSymbol');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Show transaction confirmed notification
  Future<void> showTransactionConfirmed({
    required String coinSymbol,
    required String txHash,
  }) async {
    if (!_initialized) {
      print('⚠️ Notifications not initialized');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for confirmed transactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        txHash.hashCode.abs() % 2147483647,
        '✓ Transaction Confirmed',
        'Your $coinSymbol transaction has been confirmed',
        details,
        payload: txHash,
      );
      print('✅ Notification shown: Transaction confirmed');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      try {
        final granted = await androidPlugin.requestNotificationsPermission();
        print('Notification permission: ${granted == true ? "granted" : "denied"}');
        return granted ?? false;
      } catch (e) {
        print('❌ Error requesting notification permission: $e');
        return false;
      }
    }

    return false;
  }

  // Test notification (for debugging)
  Future<void> showTestNotification() async {
    await showTransactionReceived(
      coinSymbol: 'ETH',
      amount: 0.1,
      txHash: 'test_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}