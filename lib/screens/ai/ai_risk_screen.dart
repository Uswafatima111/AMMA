import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/risk_result.dart';
import '../../services/ai_risk_service.dart';

class AiRiskScreen extends StatelessWidget {
  const AiRiskScreen({
    super.key,
    required this.pregnancyWeek,
  });

  final int pregnancyWeek;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No authenticated patient found.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AMMA AI Risk Assessment'),
      ),
      body: FutureBuilder<RiskResult?>(
        future: AiRiskService().assessLatestRecord(
          userId: user.uid,
          pregnancyWeek: pregnancyWeek,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to perform the AI risk assessment.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final result = snapshot.data;

          if (result == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No health records are available yet. '
                  'Add a health record to perform an assessment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          }

          return _RiskResultView(result: result);
        },
      ),
    );
  }
}

class _RiskResultView extends StatelessWidget {
  const _RiskResultView({
    required this.result,
  });

  final RiskResult result;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AMMA AI',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Maternal Risk Assessment',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Assessment generated from the latest '
            'health information stored in the patient record.',
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Risk Level',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    result.riskLevel.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Assessment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(result.explanation),

                  const SizedBox(height: 20),

                  const Text(
                    'Detected Factors',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...result.matchedRules.map(
                    (rule) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(rule),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Recommended Next Step',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(result.recommendation),

                  const SizedBox(height: 20),

                  Text(
                    'Rule version: ${result.ruleVersion}',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Important: This assessment is a decision-support '
            'feature and does not replace professional medical '
            'evaluation.',
            style: TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}