import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/planned_garde.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Essaie de définir le fuseau Europe/Paris
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    } catch (e) {
      debugPrint('Timezone Europe/Paris non chargé : $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    // Demande la permission Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  // Programme une alarme pour une garde planifiée
  // Rappel 1h avant + rappel le matin du jour J
  static Future<void> programmerAlarme(PlannedGarde g) async {
    await init();
    await annulerAlarme(g.id);

    final dateGarde = DateTime(g.date.year, g.date.month, g.date.day,
        g.heureDebutH, g.heureDebutM);

    // Rappel 1h avant le début
    final rappel1h = dateGarde.subtract(const Duration(hours: 1));
    if (rappel1h.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _idFrom(g.id, 0),
        '🚑 Garde dans 1 heure',
        'Votre garde commence à ${g.heureDebutH.toString().padLeft(2,"0")}h${g.heureDebutM.toString().padLeft(2,"0")}',
        tz.TZDateTime.from(rappel1h, tz.local),
        _notifDetails('garde_rappel'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Rappel le matin du jour J à 6h
    final matin = DateTime(g.date.year, g.date.month, g.date.day, 6, 0);
    if (matin.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _idFrom(g.id, 1),
        '🚑 Garde aujourd\'hui',
        'Prise de service à ${g.heureDebutH.toString().padLeft(2,"0")}h${g.heureDebutM.toString().padLeft(2,"0")}',
        tz.TZDateTime.from(matin, tz.local),
        _notifDetails('garde_matin'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // Annule toutes les alarmes d'une garde
  static Future<void> annulerAlarme(String gardeId) async {
    await init();
    await _plugin.cancel(_idFrom(gardeId, 0));
    await _plugin.cancel(_idFrom(gardeId, 1));
  }

  // Annule toutes les alarmes
  static Future<void> annulerTout() async {
    await init();
    await _plugin.cancelAll();
  }

  // Reprogramme toutes les alarmes
  static Future<void> reprogrammerTout(List<PlannedGarde> gardes) async {
    await init();
    await _plugin.cancelAll();
    for (final g in gardes) {
      await programmerAlarme(g);
    }
  }

  static NotificationDetails _notifDetails(String channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channel == 'garde_rappel' ? 'Rappel garde' : 'Garde du jour',
        channelDescription: 'Alarmes pour les gardes planifiées',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static int _idFrom(String id, int offset) {
    // Espace de 214M base IDs (max int32 / 10) pour minimiser les collisions
    return (id.hashCode.abs() % 214748364) * 10 + offset;
  }
}
