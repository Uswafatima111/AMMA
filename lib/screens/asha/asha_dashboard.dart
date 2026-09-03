import 'package:flutter/material.dart';
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

          if (mothers.isEmpty) {
            return const Center(
              child: Text(
                'No mothers found.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mothers.length,
            itemBuilder: (context, index) {
              final mother = mothers[index].data();

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
            },
          );
        },
      ),
    );
  }
}