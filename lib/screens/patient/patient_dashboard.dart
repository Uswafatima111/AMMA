import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/alert_service.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/health_record_service.dart';
import '../login_screen.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No authenticated user found.'),
        ),
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
          if (motherSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                const Icon(
                  Icons.pregnant_woman,
                  size: 70,
                ),

                const SizedBox(height: 16),

                Text(
                  'Welcome, ${mother['name']}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                // Maternal profile
                const Text(
                  'My Pregnancy',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.pregnant_woman,
                    ),
                    title: const Text('Pregnancy Week'),
                    subtitle: Text(
                      'Week ${mother['pregnancyWeek']}',
                    ),
                  ),
                ),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                    ),
                    title: const Text('Status'),
                    subtitle: Text(
                      '${mother['status']}',
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Health records
                const Text(
                  'Health Records',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: HealthRecordService()
                      .getHealthRecords(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Unable to load health records.',
                          ),
                        ),
                      );
                    }

                    final records = snapshot.data?.docs ?? [];

                    if (records.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No health records found.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: records.map((record) {
                        final data = record.data();

                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.health_and_safety,
                            ),
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: AppointmentService()
                      .getAppointments(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Unable to load appointments.',
                          ),
                        ),
                      );
                    }

                    final appointments =
                        snapshot.data?.docs ?? [];

                    if (appointments.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No appointments found.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children:
                          appointments.map((appointment) {
                        final data = appointment.data();

                        final timestamp =
                            data['date'] as Timestamp?;

                        final date = timestamp?.toDate();

                        final formattedDate = date == null
                            ? 'Date not available'
                            : '${date.day}/'
                                '${date.month}/'
                                '${date.year}';

                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.calendar_month,
                            ),
                            title: Text(
                              '${data['title']}',
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

                // Alerts
                const Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: AlertService().getAlerts(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Unable to load alerts.',
                          ),
                        ),
                      );
                    }

                    final alerts = snapshot.data?.docs ?? [];

                    if (alerts.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No alerts at the moment.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: alerts.map((alert) {
                        final data = alert.data();

                        final isRead = data['isRead'] == true;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                            ),
                            title: Text(
                              '${data['title']}',
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${data['message']}',
                            ),
                            trailing: isRead
                                ? null
                                : const Icon(
                                    Icons.circle,
                                    size: 10,
                                  ),
                            onTap: () async {
                              if (!isRead) {
                                await AlertService().markAsRead(
                                  alert.id,
                                );
                              }
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Patient ID: ${user.uid}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}