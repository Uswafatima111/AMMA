import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/appointment_service.dart';
import '../../services/alert_service.dart';
import '../../services/health_record_service.dart';
import '../../services/reminder_service.dart';
import 'asha_medicine_reminders_section.dart';
import 'asha_help_requests_section.dart';

class MotherDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> mother;

  const MotherDetailsScreen({super.key, required this.mother});

  @override
  Widget build(BuildContext context) {
    final motherId = mother['id'] as String;
    final patientUid = mother['patientUid'] as String? ??
        mother['userId'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Mother Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.pregnant_woman, size: 80),

            Text(
              '${mother['name']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(Icons.pregnant_woman),
                title: const Text('Pregnancy Week'),
                subtitle: Text(
                  'Week ${mother['pregnancyWeek'] ?? mother['gestationalWeeks'] ?? 'Not recorded'}',
                ),
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

            const Text(
              'Patient Help Requests',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            AshaHelpRequestsSection(
              motherId: mother['id'] as String,
              alertService: AlertService(),
            ),

            const SizedBox(height: 24),

            const Text(
              'Health Records',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: HealthRecordService().getHealthRecords(motherId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                        title: Text('Blood Pressure: ${data['bloodPressure']}'),
                        subtitle: Text(
                          'Weight: ${data['weight']} kg\n'
                          'Hemoglobin: ${data['hemoglobin']} g/dL\n'
                          'Notes: ${data['notes']}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            const Text(
              'Appointments',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppointmentService().getAppointments(motherId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Unable to load appointments.'),
                    ),
                  );
                }

                final appointments = snapshot.data?.docs ?? [];

                if (appointments.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No appointments found.'),
                    ),
                  );
                }

                return Column(
                  children: appointments.map((appointment) {
                    final data = appointment.data();

                    final date = data['date'] as Timestamp?;
                    final appointmentDate = date?.toDate();

                    final formattedDate = appointmentDate == null
                        ? 'Date not available'
                        : '${appointmentDate.day}/'
                              '${appointmentDate.month}/'
                              '${appointmentDate.year}';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: Text(
                          '${data['title'] ?? data['facilityName'] ?? 'Appointment'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Doctor: ${data['doctorName']}\n'
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

            const SizedBox(height: 20),

            const SizedBox(height: 28),

            AshaMedicineRemindersSection(
              motherId: mother['id'] as String,
              reminderService: ReminderService(),
            ),

            const SizedBox(height: 20),

            Text(
              'Patient ID: ${patientUid ?? 'Not linked'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
