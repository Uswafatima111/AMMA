import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../ai/ai_risk_screen.dart';
import '../ai/amma_chat_screen.dart';
import '../../services/alert_service.dart';
import '../../services/asha_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/health_record_service.dart';
import '../../services/reminder_service.dart';
import '../emergency/emergency_screen.dart';
import '../login_screen.dart';
import 'patient_local_reminder_controls.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AMMA - Patient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: FirestoreService().getMother(user.uid),
        builder: (context, motherSnapshot) {
          if (motherSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (motherSnapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load your profile.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final mother = motherSnapshot.data;

          if (mother == null) {
            return const Center(
              child: Text(
                'No maternal profile found.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pregnant_woman, size: 70),

                const SizedBox(height: 16),

                Text(
                  'Welcome, ${mother['name']}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Emergency SOS
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmergencyScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.emergency),
                    label: const Text(
                      'EMERGENCY SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                PatientAshaContactCard(service: AshaService()),

                const SizedBox(height: 16),

                // AMMA AI Risk Check
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final pregnancyWeek =
                          (mother['pregnancyWeek'] as num?)?.toInt() ?? 0;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AiRiskScreen(pregnancyWeek: pregnancyWeek),
                        ),
                      );
                    },
                    icon: const Icon(Icons.psychology),
                    label: const Text(
                      'AMMA AI RISK CHECK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // AMMA AI Assistant
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AmmaChatScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text(
                      'AMMA AI ASSISTANT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Maternal profile
                const Text(
                  'My Pregnancy',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.pregnant_woman),
                    title: const Text('Pregnancy Week'),
                    subtitle: Text('Week ${mother['pregnancyWeek']}'),
                  ),
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Status'),
                    subtitle: Text('${mother['status']}'),
                  ),
                ),

                const SizedBox(height: 24),

                // Health records
                const Text(
                  'Health Records',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: HealthRecordService().getHealthRecords(user.uid),
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
                          child: Text('Unable to load health records.'),
                        ),
                      );
                    }

                    final records = snapshot.data?.docs ?? [];

                    if (records.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No health records found.'),
                        ),
                      );
                    }

                    return Column(
                      children: records.map((record) {
                        final data = record.data();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.health_and_safety),
                            title: Text(
                              'Blood Pressure: '
                              '${data['bloodPressure']}',
                            ),
                            subtitle: Text(
                              'Weight: ${data['weight']} kg\n'
                              'Hemoglobin: '
                              '${data['hemoglobin']} g/dL\n'
                              'Notes: ${data['notes']}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Appointments
                const Text(
                  'Appointments',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                PatientLocalReminderControls(
                  patientUid: user.uid,
                  motherId: mother['id'] as String,
                ),

                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: AppointmentService().watchAppointmentsForMother(
                    mother['id'] as String,
                  ),
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
                          child: Text('Unable to load appointments.'),
                        ),
                      );
                    }

                    final appointments = snapshot.data ?? [];

                    if (appointments.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No appointments found.'),
                        ),
                      );
                    }

                    return Column(
                      children: appointments.map((data) {
                        final value = data['date'];
                        final date = value is Timestamp
                            ? value.toDate()
                            : value is DateTime
                            ? value
                            : null;

                        final formattedDate = date == null
                            ? 'Date not available'
                            : '${date.day}/'
                                  '${date.month}/'
                                  '${date.year}';

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: Text(
                              '${data['title'] ?? data['facilityName'] ?? 'Appointment'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Doctor: '
                              '${data['doctorName']}\n'
                              'Date: $formattedDate\n'
                              'Status: ${data['status']}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Text(
                  'Medicine reminders',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ReminderService().watchForMother(
                    mother['id'] as String,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Unable to load medicine reminders.'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final reminders = snapshot.data!.docs;
                    if (reminders.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No medicine reminders found.'),
                        ),
                      );
                    }
                    return Column(
                      children: reminders.map((reminder) {
                        final data = reminder.data();
                        final active = data['active'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              active ? Icons.medication : Icons.pause_circle,
                            ),
                            title: Text('${data['medicineName']}'),
                            subtitle: Text(
                              '${data['instructions']}\n'
                              'Time: ${data['reminderTime']} · '
                              '${active ? 'Active' : 'Inactive'}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                const PatientHelpRequestCard(),

                const SizedBox(height: 24),

                // Alerts
                const Text(
                  'Alerts',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AlertService().getAlerts(user.uid),
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
                          child: Text('Unable to load alerts.'),
                        ),
                      );
                    }

                    final alerts = snapshot.data?.docs ?? [];

                    if (alerts.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No alerts at the moment.'),
                        ),
                      );
                    }

                    return Column(
                      children: alerts.map((alert) {
                        final data = alert.data();

                        final isRead =
                            data['isRead'] == true || data['status'] == 'read';
                        final title = data['title'] ?? switch (data['type']) {
                          'benefit_help' => 'Benefit help request',
                          'appointment_request' => 'Appointment request',
                          _ => 'Alert',
                        };

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                            ),
                            title: Text(
                              '$title',
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${data['message']}'),
                            trailing: isRead
                                ? null
                                : const Icon(Icons.circle, size: 10),
                            // Patient help requests are read-only. Acknowledging
                            // and changing their status is an ASHA workflow.
                            onTap: null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Patient ID: ${user.uid}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PatientAshaContactCard extends StatefulWidget {
  const PatientAshaContactCard({super.key, required this.service});

  final AshaService service;

  @override
  State<PatientAshaContactCard> createState() => _PatientAshaContactCardState();
}

class _PatientAshaContactCardState extends State<PatientAshaContactCard> {
  late final Future<Map<String, dynamic>?> _contact;

  @override
  void initState() {
    super.initState();
    _contact = widget.service.getAshaContact();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _contact,
    builder: (context, snapshot) {
      final contact = snapshot.data;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.support_agent),
          title: Text(
            contact?['name']?.toString().trim().isNotEmpty == true
                ? contact!['name'].toString()
                : 'Assigned ASHA',
          ),
          subtitle: Text(
            snapshot.connectionState == ConnectionState.waiting
                ? 'Loading contact details…'
                : snapshot.hasError || contact == null
                ? 'ASHA contact details are unavailable.'
                : (contact['phone']?.toString().trim().isNotEmpty == true
                      ? contact!['phone'].toString()
                      : 'Phone number not provided.'),
          ),
        ),
      );
    },
  );
}

class PatientHelpRequestCard extends StatefulWidget {
  const PatientHelpRequestCard({super.key});

  @override
  State<PatientHelpRequestCard> createState() => _PatientHelpRequestCardState();
}

class _PatientHelpRequestCardState extends State<PatientHelpRequestCard> {
  final AlertService _alertService = AlertService();
  bool _submitting = false;

  Future<void> _submitRequest(String type) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          type == 'benefit_help' ? 'Request benefit help' : 'Request an appointment',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'How can your ASHA help?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.trim().isEmpty || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _alertService.createPatientHelpRequest(type: type, message: message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request saved. It does not automatically notify your ASHA.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save your request. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Request help',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Requests are stored in AMMA; no notification is sent.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : () => _submitRequest('benefit_help'),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Benefit help'),
          ),
          OutlinedButton.icon(
            onPressed: _submitting
                ? null
                : () => _submitRequest('appointment_request'),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Appointment request'),
          ),
        ],
      ),
    ),
  );
}
