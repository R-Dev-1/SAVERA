import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

/// Handler top-level untuk callback aksi notifikasi saat aplikasi berjalan di background isolate.
/// WAJIB menggunakan @pragma('vm:entry-point') agar tidak di-strip oleh tree-shaking / ProGuard saat build release.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == EmergencyAlertService.actionDismissId ||
      notificationResponse.notificationResponseType ==
          NotificationResponseType.selectedNotificationAction) {
    EmergencyAlertService().stopAlert();
    EmergencyAlertService().onAlarmDismissedByUser?.call();
  }
}

/// Service khusus untuk menangani Peringatan Darurat Jatuh (Fall Detection Alert)
/// Mendukung notifikasi sistem high-priority, alarm suara berulang (loop),
/// dan integrasi dengan foreground dialog.
class EmergencyAlertService {
  static final EmergencyAlertService _instance =
      EmergencyAlertService._internal();
  factory EmergencyAlertService() => _instance;
  EmergencyAlertService._internal();

  static const int emergencyNotificationId = 999;
  static const String channelId = 'savera_emergency_channel_v1';
  static const String channelName = 'Peringatan Darurat Jatuh';
  static const String channelDescription =
      'Notifikasi darurat saat pasien lansia terdeteksi jatuh';
  static const String actionDismissId = 'dismiss_alarm';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _audioPlayer;

  bool _isAlerting = false;
  bool _isInitialized = false;

  /// Callback jika pengguna menekan tombol aksi "Matikan Alarm & Paham" pada notifikasi
  VoidCallback? onAlarmDismissedByUser;

  bool get isAlerting => _isAlerting;

  /// Inisialisasi plugin notifikasi dan pembuatan Android Notification Channel
  Future<void> initialize({VoidCallback? onDismiss}) async {
    if (onDismiss != null) {
      onAlarmDismissedByUser = onDismiss;
    }

    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.actionId == actionDismissId ||
              response.notificationResponseType ==
                  NotificationResponseType.selectedNotificationAction) {
            stopAlert();
            onAlarmDismissedByUser?.call();
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final vibration = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
        final channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm'),
          enableVibration: true,
          vibrationPattern: vibration,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

        await androidPlugin.createNotificationChannel(channel);

        // Minta izin notifikasi Android 13+ (POST_NOTIFICATIONS)
        await androidPlugin.requestNotificationsPermission();
        // Minta izin Full Screen Intent jika didukung
        await androidPlugin.requestFullScreenIntentPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[EmergencyAlertService] Inisialisasi error: $e');
    }
  }

  /// Memulai peringatan darurat: memutar suara alarm berulang (loop)
  /// dan menampilkan notifikasi high-priority jika diperlukan (misal saat di background).
  Future<void> triggerAlert({
    String title = 'PERINGATAN DARURAT!',
    String body = 'Sistem mendeteksi pasien terjatuh!',
    bool showNotification = true,
  }) async {
    _isAlerting = true;

    // 1. Memutar suara alarm secara berulang (loop)
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      debugPrint('[EmergencyAlertService] Gagal memutar audio alarm: $e');
    }

    // 2. Tampilkan High-Priority Local Notification dengan getaran dan tombol dismiss
    if (showNotification) {
      await showBackgroundNotification(title: title, body: body);
    }
  }

  /// Menampilkan notifikasi heads-up darurat
  Future<void> showBackgroundNotification({
    String title = 'PERINGATAN DARURAT!',
    String body = 'Sistem mendeteksi pasien terjatuh!',
  }) async {
    try {
      final vibration = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        vibrationPattern: vibration,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        actions: const [
          AndroidNotificationAction(
            actionDismissId,
            'Matikan Alarm & Paham',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        id: emergencyNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[EmergencyAlertService] Gagal menampilkan notifikasi: $e');
    }
  }

  /// Menghentikan suara alarm dan membatalkan notifikasi darurat
  Future<void> stopAlert() async {
    _isAlerting = false;

    // 1. Hentikan suara alarm
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('[EmergencyAlertService] Gagal menghentikan audio alarm: $e');
    }

    // 2. Batalkan notifikasi darurat
    try {
      await _notificationsPlugin.cancel(id: emergencyNotificationId);
    } catch (e) {
      debugPrint('[EmergencyAlertService] Gagal membatalkan notifikasi: $e');
    }
  }

  /// Bersihkan resource saat tidak digunakan
  void dispose() {
    stopAlert();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
