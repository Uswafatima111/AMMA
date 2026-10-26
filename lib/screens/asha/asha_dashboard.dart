import 'package:flutter/material.dart';

import 'asha_emergency_screen.dart';
import 'mother_details_screen.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../login_screen.dart';

class AshaDashboard extends StatelessWidget {
  const AshaDashboard({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AMMA - ASHA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirestoreService().getMothers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load mothers.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final mothers = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Emergency section.
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AshaEmergencyScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emergency),
                  label: const Text(
                    'ACTIVE EMERGENCIES',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Registered Mothers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (mothers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'No mothers found.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

              ...mothers.map((motherDocument) {
                final mother = motherDocument.data();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.pregnant_woman),
                    ),
                    title: Text(
                      '${mother['name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Pregnancy Week: ${mother['pregnancyWeek']}\n'
                      'Status: ${mother['status']}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MotherDetailsScreen(
                            mother: mother,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}