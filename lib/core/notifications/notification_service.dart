import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../native/models/network_source.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    // Create notification channels on Android
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      const alertChannel = AndroidNotificationChannel(
        'kayto_alerts_channel',
        'Kayto Usage Warnings',
        description: 'Notifies when apps reach 50%, 70%, or 90% of daily data quota',
        importance: Importance.high,
      );

      const enforcementChannel = AndroidNotificationChannel(
        'kayto_enforcement_channel',
        'Kayto Enforcement Actions',
        description: 'Notifies when an app exceeds 100% of its quota and is blocked',
        importance: Importance.high,
      );

      await androidImpl.createNotificationChannel(alertChannel);
      await androidImpl.createNotificationChannel(enforcementChannel);
    }
  }

  Future<void> showLimitAlert({
    required int id,
    required String appLabel,
    required NetworkSource source,
    required int threshold,
  }) async {
    final sourceName = source.displayName;
    final isEnforcement = (threshold == 100);

    final title = isEnforcement
        ? '$appLabel blocked on $sourceName'
        : 'Quota warning: $appLabel ($threshold%)';

    final body = isEnforcement
        ? '$appLabel reached 100% of its $sourceName daily quota. $sourceName access has been blocked.'
        : '$appLabel has reached $threshold% of its $sourceName daily quota.';

    final channelId = isEnforcement
        ? 'kayto_enforcement_channel'
        : 'kayto_alerts_channel';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
