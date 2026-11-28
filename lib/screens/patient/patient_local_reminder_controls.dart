import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/patient_local_reminder_service.dart';

class PatientLocalReminderControls extends StatefulWidget {
  const PatientLocalReminderControls({
    required this.patientUid,
    required this.motherId,
    super.key,
  });

  final String patientUid;
  final String motherId;

  @override
  State<PatientLocalReminderControls> createState() =>
      _PatientLocalReminderControlsState();
}

class _PatientLocalReminderControlsState
    extends State<PatientLocalReminderControls> {
  late final PatientLocalReminderService _service;
  bool _busy = false;
  bool _enabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _service = PatientLocalReminderService();
  }

  @override
  void dispose() {
    unawaited(_service.stop());
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final granted = await _service.enableForPatient(
        patientUid: widget.patientUid,
        motherId: widget.motherId,
      );
      if (!mounted) return;
      setState(() {
        _enabled = granted;
        _message = granted
            ? 'Local reminders are enabled on this device.'
            : 'Notification permission was not granted.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Unable to enable local reminders.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local reminders',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reminders are scheduled on this device. They are not sent to '
            'your ASHA or to another device.',
          ),
          const SizedBox(height: 8),
          if (!_enabled)
            FilledButton.icon(
              onPressed: _busy ? null : _enable,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text('Enable local reminders'),
            )
          else
            const Text('Enabled for this device session.'),
          if (_message != null) ...[const SizedBox(height: 6), Text(_message!)],
        ],
      ),
    ),
  );
}
