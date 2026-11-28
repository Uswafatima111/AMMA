import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/medicine_reminder_model.dart';
import '../../services/reminder_service.dart';

class AshaMedicineRemindersSection extends StatelessWidget {
  const AshaMedicineRemindersSection({
    required this.motherId,
    required this.reminderService,
    super.key,
  });

  final String motherId;
  final ReminderService reminderService;

  Future<void> _editReminder(
    BuildContext context, {
    MedicineReminderModel? reminder,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ReminderEditorDialog(
        reminder: reminder,
        onSave: (medicineName, instructions, startDate, endDate, time) async {
          if (reminder == null) {
            await reminderService.createReminder(
              motherId: motherId,
              medicineName: medicineName,
              instructions: instructions,
              startDate: startDate,
              endDate: endDate,
              reminderTime: time,
            );
          } else {
            await reminderService.updateReminder(
              reminderId: reminder.id,
              medicineName: medicineName,
              instructions: instructions,
              startDate: startDate,
              endDate: endDate,
              reminderTime: time,
            );
          }
        },
      ),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    MedicineReminderModel reminder,
    bool active,
  ) async {
    try {
      await reminderService.setActive(reminderId: reminder.id, active: active);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update this reminder.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Medicine reminders',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('reminder.create'),
            onPressed: () => _editReminder(context),
            icon: const Icon(Icons.add),
            label: const Text('Create reminder'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reminderService.watchForMother(motherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Unable to load medicine reminders.'),
              ),
            );
          }
          final reminders = snapshot.data?.docs ?? [];
          if (reminders.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No medicine reminders for this mother.'),
              ),
            );
          }
          return Column(
            children: reminders.map((document) {
              final reminder = MedicineReminderModel.fromMap(
                document.id,
                document.data(),
              );
              return Card(
                child: ListTile(
                  key: ValueKey('reminder.tile.${reminder.id}'),
                  leading: Icon(
                    reminder.active ? Icons.medication : Icons.pause_circle,
                  ),
                  title: Text(reminder.medicineName),
                  subtitle: Text(
                    '${reminder.instructions}\n'
                    '${_dateLabel(reminder.startDate)} – '
                    '${_dateLabel(reminder.endDate)} · ${reminder.reminderTime}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('reminder.edit.${reminder.id}'),
                        tooltip: 'Edit reminder',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _editReminder(context, reminder: reminder),
                      ),
                      Switch(
                        key: ValueKey('reminder.active.${reminder.id}'),
                        value: reminder.active,
                        onChanged: (value) =>
                            _setActive(context, reminder, value),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Enter only the instructions provided by the care team. '
          'This screen does not recommend medicines or doses.',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  static String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

typedef _SaveReminder =
    Future<void> Function(
      String medicineName,
      String instructions,
      DateTime startDate,
      DateTime endDate,
      String reminderTime,
    );

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({this.reminder, required this.onSave});

  final MedicineReminderModel? reminder;
  final _SaveReminder onSave;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _medicineController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _timeController;
  bool _saving = false;
  String? _error;

  String _dateValue(DateTime? date) {
    if (date == null) {
      final today = DateTime.now();
      return '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
    }
    return AshaMedicineRemindersSection._dateLabel(date);
  }

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _medicineController = TextEditingController(
      text: reminder?.medicineName ?? '',
    );
    _instructionsController = TextEditingController(
      text: reminder?.instructions ?? '',
    );
    _startController = TextEditingController(
      text: _dateValue(reminder?.startDate),
    );
    _endController = TextEditingController(text: _dateValue(reminder?.endDate));
    _timeController = TextEditingController(
      text: reminder?.reminderTime ?? '08:00',
    );
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _instructionsController.dispose();
    _startController.dispose();
    _endController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null || value.trim() != _dateValue(parsed)) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final start = _parseDate(_startController.text)!;
    final end = _parseDate(_endController.text)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _medicineController.text,
        _instructionsController.text,
        start,
        end,
        _timeController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Unable to save. Check your assignment and reminder details.';
        });
      }
    }
  }

  String? _required(String? value, String label, int maxLength) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    if (value.trim().length > maxLength) return '$label is too long.';
    return null;
  }

  String? _dateValidator(String? value) =>
      value == null || _parseDate(value) == null
      ? 'Use a date in YYYY-MM-DD format.'
      : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.reminder == null ? 'Create reminder' : 'Edit reminder'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('reminder.form.medicine'),
                controller: _medicineController,
                decoration: const InputDecoration(labelText: 'Medicine name'),
                validator: (value) => _required(value, 'Medicine name', 120),
              ),
              TextFormField(
                key: const ValueKey('reminder.form.instructions'),
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Care-team instructions',
                ),
                maxLines: 2,
                validator: (value) => _required(value, 'Instructions', 1000),
              ),
              TextFormField(
                key: const ValueKey('reminder.form.start'),
                controller: _startController,
                decoration: const InputDecoration(
                  labelText: 'Start date (YYYY-MM-DD)',
                ),
                validator: _dateValidator,
              ),
              TextFormField(
                key: const ValueKey('reminder.form.end'),
                controller: _endController,
                decoration: const InputDecoration(
                  labelText: 'End date (YYYY-MM-DD)',
                ),
                validator: _dateValidator,
              ),
              TextFormField(
                key: const ValueKey('reminder.form.time'),
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Reminder time (24-hour HH:mm)',
                ),
                validator: (value) =>
                    value != null &&
                        RegExp(
                          r'^(?:[01]\d|2[0-3]):[0-5]\d$',
                        ).hasMatch(value.trim())
                    ? null
                    : 'Enter a valid time in HH:mm format.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('reminder.form.save'),
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Saving…' : 'Save reminder'),
      ),
    ],
  );
}
