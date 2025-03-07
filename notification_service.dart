import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = true; // Track notification state

  NotificationService() {
    _initializeNotifications();
    _loadNotificationPreference(); // Load the saved preference
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _createNotificationChannel(); // Create the notification channel
  }

  void _createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'channel_id', // Unique channel ID
        'Distance and Fuel Notification', // Channel name
        description: 'Notifications for distance and fuel needed',
        importance: Importance.high,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Load notification preference from SharedPreferences
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true; // Default to true if not set
  }

  // Method to toggle notifications on and off
  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled); // Save the state
  }

  Future<void> showDistanceAndFuelNotification(String totalDistance, String fuelNeeded) async {
    if (!_notificationsEnabled) return; // Check if notifications are enabled

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'channel_id', // Unique channel ID
      'Distance and Fuel Notification', // Channel name
      channelDescription: 'Notifications for distance and fuel needed',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Trip Information', // Notification title
      '$totalDistance\n$fuelNeeded', // Notification body
      notificationDetails,
    );
  }

  // Method to check if notifications are enabled
  bool areNotificationsEnabled() {
    return _notificationsEnabled;
  }
}