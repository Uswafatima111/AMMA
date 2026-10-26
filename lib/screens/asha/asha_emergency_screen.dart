import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/emergency_service.dart';

class AshaEmergencyScreen extends StatelessWidget {
  const AshaEmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emergencyService = EmergencyService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Requests'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: emergencyService.getActiveEmergencies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load emergency requests.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final emergencies = snapshot.data?.docs ?? [];

          if (emergencies.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No Active Emergencies',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'There are currently no active emergency requests.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: emergencies.length,
            itemBuilder: (context, index) {
              final emergency = emergencies[index].data();
              final emergencyId = emergencies[index].id;

              return _EmergencyCard(
                emergency: emergency,
                emergencyId: emergencyId,
                emergencyService: emergencyService,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> emergency;
  final String emergencyId;
  final EmergencyService emergencyService;

  const _EmergencyCard({
    required this.emergency,
    required this.emergencyId,
    required this.emergencyService,
  });

  @override
  Widget build(BuildContext context) {
    final patientId =
        emergency['patientId'] as String? ?? 'Unknown patient';

    final message =
        emergency['message'] as String? ?? 'Emergency reported.';

    final type =
        emergency['type'] as String? ?? 'medical_emergency';

    final severity =
        emergency['severity'] as String? ?? 'critical';

    final status =
        emergency['status'] as String? ?? 'active';

    final createdAt = emergency['createdAt'];

    String timeText = 'Time unavailable';

    if (createdAt is Timestamp) {
      timeText = createdAt.toDate().toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  size: 32,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ACTIVE EMERGENCY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    severity.toUpperCase(),
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            Text(
              message,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 14),

            _InfoRow(
              icon: Icons.person,
              label: 'Patient ID',
              value: patientId,
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.medical_services,
              label: 'Type',
              value: type,
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.access_time,
              label: 'Created',
              value: timeText,
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: status,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No authenticated ASHA user found.',
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await emergencyService.respondToEmergency(
                      emergencyId: emergencyId,
                      responderId: user.uid,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Emergency response recorded.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to respond to emergency.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text(
                  'RESPOND TO EMERGENCY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await emergencyService.resolveEmergency(
                      emergencyId,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Emergency marked as resolved.',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to resolve emergency.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.done_all),
                label: const Text(
                  'MARK AS RESOLVED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}