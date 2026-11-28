import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/alert_service.dart';

class AshaHelpRequestsSection extends StatelessWidget {
  final String motherId;
  final AlertService alertService;

  const AshaHelpRequestsSection({
    super.key,
    required this.motherId,
    required this.alertService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: alertService.watchAlertsForMother(motherId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Unable to load help requests.'),
            ),
          );
        }

        final requests = (snapshot.data ?? [])
            .where(
              (alert) =>
                  AlertService.patientHelpRequestTypes.contains(alert['type']),
            )
            .toList();
        if (requests.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No help requests.'),
            ),
          );
        }

        return Column(
          children: requests.map((request) {
            final alertId = request['id'] as String;
            final status = request['status'] as String? ?? 'unknown';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(_requestTitle(request['type'] as String)),
                subtitle: Text('Status: $status'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openRequest(context, alertId, request),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _openRequest(
    BuildContext context,
    String alertId,
    Map<String, dynamic> request,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_requestTitle(request['type'] as String)),
        content: Text(request['message'] as String? ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (request['status'] == 'open') {
      unawaited(_acknowledgeWithoutBlocking(context, alertId));
    }
  }

  Future<void> _acknowledgeWithoutBlocking(
    BuildContext context,
    String alertId,
  ) async {
    try {
      await alertService.markAsReadIfOpen(alertId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to acknowledge this request.')),
      );
    }
  }

  String _requestTitle(String type) => switch (type) {
    'benefit_help' => 'Benefit help request',
    'appointment_request' => 'Appointment request',
    _ => 'Help request',
  };
}
