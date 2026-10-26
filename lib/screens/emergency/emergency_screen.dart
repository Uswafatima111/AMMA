import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/emergency_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final EmergencyService _emergencyService = EmergencyService();

  bool _isSending = false;

  Future<void> _sendEmergency() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('No authenticated user found.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final emergencyId =
          await _emergencyService.createEmergency(
        userId: user.uid,
        message: 'Emergency SOS activated by the patient.',
      );

      if (!mounted) return;

      _showMessage(
        'Emergency alert sent. Request ID: $emergencyId',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to send emergency alert. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _confirmEmergency() async {
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emergency SOS'),
          content: const Text(
            'Are you sure you want to send an emergency alert?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('SEND SOS'),
            ),
          ],
        );
      },
    );

    if (shouldSend == true) {
      await _sendEmergency();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emergency,
                size: 100,
              ),

              const SizedBox(height: 24),

              const Text(
                'Emergency Assistance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Press the button below to send an emergency '
                'alert to the healthcare team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed:
                      _isSending ? null : _confirmEmergency,
                  icon: _isSending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.warning),
                  label: Text(
                    _isSending
                        ? 'Sending...'
                        : 'SEND EMERGENCY SOS',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}