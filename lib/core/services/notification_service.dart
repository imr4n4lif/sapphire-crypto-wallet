import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  // Show transaction received notification
  Future<void> showTransactionReceived({
    required String coinSymbol,
    required double amount,
    required String txHash,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for incoming transactions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      txHash.hashCode,
      'Received $coinSymbol',
      'You received $amount $coinSymbol',
      details,
      payload: txHash,
    );
  }

  // Show transaction sent notification
  Future<void> showTransactionSent({
    required String coinSymbol,
    required double amount,
    required String txHash,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for outgoing transactions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      txHash.hashCode,
      'Sent $coinSymbol',
      'You sent $amount $coinSymbol',
      details,
      payload: txHash,
    );
  }

  // Show transaction confirmed notification
  Future<void> showTransactionConfirmed({
    required String coinSymbol,
    required String txHash,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'transaction_channel',
      'Transactions',
      channelDescription: 'Notifications for confirmed transactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      txHash.hashCode,
      'Transaction Confirmed',
      'Your $coinSymbol transaction has been confirmed',
      details,
      payload: txHash,
    );
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return false;
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}