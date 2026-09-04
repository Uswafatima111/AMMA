import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../core/constants/app_enums.dart';
import '../../services/firestore_service.dart';

class MothersListScreen extends StatelessWidget {
  const MothersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.ashaTheme,
      child: Scaffold(
        backgroundColor: AshaColors.background,
        appBar: AppBar(
          backgroundColor: AshaColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AshaColors.ink),
          title: Text(
            'My Mothers',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService().getMothers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load mothers: ${snapshot.error}',
                    style: GoogleFonts.inter(color: AshaColors.inkMuted),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No mothers registered yet',
                    style: GoogleFonts.inter(color: AshaColors.inkMuted),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Unknown';
                  final pregnancyWeek = data['pregnancyWeek'] as int? ?? 0;
                  final userId = data['userId'] as String? ?? docs[index].id;

                  // NOTE: Firestore doc only has name/pregnancyWeek/status
                  // right now (see createMother() gap) — the rest of
                  // MotherModel is filled with placeholders until Uswa
                  // expands what's actually saved.
                  final mother = MotherModel(
                    id: userId,
                    name: name,
                    age: 0,
                    phone: '',
                    gestationalWeeks: pregnancyWeek,
                    bloodPressure: '—',
                    weight: 0,
                    hemoglobin: 0,
                    symptoms: const [],
                    emergencyContact: '',
                    riskLevel: RiskLevel.low,
                    assignedAshaId: '',
                    createdAt: DateTime.now(),
                  );

                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/mother-profile', arguments: mother);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AshaColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AshaColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AshaColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AshaColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AshaColors.ink),
                                ),
                                Text(
                                  '$pregnancyWeek weeks',
                                  style: GoogleFonts.inter(fontSize: 12, color: AshaColors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AshaColors.inkMuted),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}