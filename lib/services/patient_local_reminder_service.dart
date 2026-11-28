import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderSchedule {
  const LocalReminderSchedule({
    required this.key,
    required this.title,
    required this.when,
  });

  final String key;
  final String title;
  final DateTime when;
}

/// Small seam for testing schedule planning without invoking the OS plugin.
abstract interface class LocalReminderGateway {
  Future<bool> requestPermission();
  Future<void> replace(List<LocalReminderSchedule> schedules);
}

class FlutterLocalReminderGateway implements LocalReminderGateway {
  FlutterLocalReminderGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return (await android.requestNotificationsPermission()) ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          )) ??
          false;
    }
    return false;
  }

  static int _notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final byte in key.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  Future<void> replace(List<LocalReminderSchedule> schedules) async {
    await _initialize();
    const payloadPrefix = 'amma-local-reminder:';
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(payloadPrefix) ?? false) {
        await _plugin.cancel(request.id);
      }
    }
    for (final schedule in schedules.take(
      PatientLocalReminderService.maxSchedules,
    )) {
      await _plugin.zonedSchedule(
        _notificationId(schedule.key),
        schedule.title,
        'A reminder is due. Open AMMA for details.',
        tz.TZDateTime.from(schedule.when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'amma_local_reminders',
            'AMMA reminders',
            channelDescription: 'Locally scheduled care reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$payloadPrefix${schedule.key}',
      );
    }
  }
}

/// Manages patient-consented, device-local schedules from scoped Firestore
/// streams. No notification is sent to Firebase or another device.
class PatientLocalReminderService {
  PatientLocalReminderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocalReminderGateway? gateway,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _gateway = gateway ?? FlutterLocalReminderGateway();

  static const int maxSchedules = 60;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocalReminderGateway _gateway;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _motherAppointments = [];
  List<Map<String, dynamic>> _legacyAppointments = [];
  List<Map<String, dynamic>> _reminders = [];
  bool _enabled = false;
  Future<void> _syncQueue = Future<void>.value();

  static List<LocalReminderSchedule> plan({
    required List<Map<String, dynamic>> appointments,
    required List<Map<String, dynamic>> reminders,
    required DateTime now,
    int limit = maxSchedules,
  }) {
    final schedules = <LocalReminderSchedule>[];
    for (final row in appointments) {
      if (row['reminderEnabled'] != true ||
          !{'pending', 'scheduled'}.contains(row['status'] ?? 'scheduled')) {
        continue;
      }
      final date = _date(row['date']);
      if (date != null && date.isAfter(now)) {
        schedules.add(
          LocalReminderSchedule(
            key: 'appointment:${row['id'] ?? ''}',
            title: 'Appointment reminder',
            when: date,
          ),
        );
      }
    }
    for (final row in reminders) {
      if (row['active'] != true) continue;
      final start = _calendarDate(row['startDate']);
      final end = _calendarDate(row['endDate']);
      final time = row['reminderTime'];
      if (start == null ||
          end == null ||
          time is! String ||
          !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
        continue;
      }
      final startDay = DateTime.utc(start.year, start.month, start.day);
      final endDay = DateTime.utc(end.year, end.month, end.day);
      final today = DateTime.utc(now.year, now.month, now.day);
      var day = startDay.isBefore(today) ? today : startDay;
      final parts = time.split(':').map(int.parse).toList();
      while (!day.isAfter(endDay)) {
        final occurrence = DateTime(
          day.year,
          day.month,
          day.day,
          parts[0],
          parts[1],
        );
        if (occurrence.isAfter(now)) {
          schedules.add(
            LocalReminderSchedule(
              key: 'medicine:${row['id'] ?? ''}:${day.toIso8601String()}',
              title: 'Medicine reminder',
              when: occurrence,
            ),
          );
        }
        day = day.add(const Duration(days: 1));
      }
    }
    schedules.sort((a, b) => a.when.compareTo(b.when));
    return schedules.take(limit).toList(growable: false);
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // Reminder date fields are stored as UTC midnight dates, not instants. Keep
  // their UTC calendar components when converting to the device's local time.
  static DateTime? _calendarDate(Object? value) {
    if (value is Timestamp) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.millisecondsSinceEpoch,
        isUtc: true,
      );
    }
    if (value is DateTime) return value.toUtc();
    return null;
  }

  Future<bool> enableForPatient({
    required String patientUid,
    required String motherId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || uid != patientUid) {
      throw StateError('Only the signed-in patient can enable reminders.');
    }
    final profile = await _firestore.collection('users').doc(uid).get();
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    final data = mother.data();
    final profileMotherId = profile.data()?['assignedMotherId'];
    if (!profile.exists ||
        profile.data()?['role'] != 'patient' ||
        !mother.exists ||
        (profileMotherId is String && profileMotherId != motherId) ||
        (data?['patientUid'] != uid &&
            !(data?['patientUid'] == null && motherId == uid))) {
      throw StateError('The maternal record is not linked to this patient.');
    }
    if (!await _gateway.requestPermission()) return false;

    await stop();
    _enabled = true;
    final appointments = _firestore.collection('appointments');
    _subscriptions.add(
      appointments.where('motherId', isEqualTo: motherId).snapshots().listen((
        snapshot,
      ) {
        _motherAppointments = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        unawaited(_syncSafely());
      }, onError: (_) {}),
    );
    _subscriptions.add(
      appointments.where('userId', isEqualTo: uid).snapshots().listen((
        snapshot,
      ) {
        _legacyAppointments = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        unawaited(_syncSafely());
      }, onError: (_) {}),
    );
    _subscriptions.add(
      _firestore
          .collection('medicine_reminders')
          .where('motherId', isEqualTo: motherId)
          .snapshots()
          .listen((snapshot) {
            _reminders = snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList();
            unawaited(_syncSafely());
          }, onError: (_) {}),
    );
    return true;
  }

  Future<void> _syncSafely() {
    if (!_enabled) return Future<void>.value();
    final schedules = plan(
      appointments: [..._motherAppointments, ..._legacyAppointments]
          .fold<Map<String, Map<String, dynamic>>>(
            {},
            (map, row) => map..[row['id'] as String] = row,
          )
          .values
          .toList(),
      reminders: _reminders,
      now: DateTime.now(),
    );
    _syncQueue = _syncQueue
        .catchError((_) {})
        .then((_) => _gateway.replace(schedules))
        .catchError((_) {
          // Firestore/plugin failures do not propagate into patient UI.
        });
    return _syncQueue;
  }

  Future<void> stop() async {
    _enabled = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _motherAppointments = [];
    _legacyAppointments = [];
    _reminders = [];
  }
}
