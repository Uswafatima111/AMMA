import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../core/constants/app_enums.dart';
import '../../services/firestore_service.dart';

class AshaDashboardScreen extends StatelessWidget {
  const AshaDashboardScreen({super.key});

  static const String workerName = 'Kavya';
  static const bool isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.ashaTheme,
      child: Scaffold(
        backgroundColor: AshaColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(workerName: workerName, isOnline: isOnline),
                const SizedBox(height: 24),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search mothers by name',
                    hintStyle: GoogleFonts.inter(color: AshaColors.inkMuted),
                    prefixIcon: const Icon(Icons.search, color: AshaColors.inkMuted),
                  ),
                ),
                const SizedBox(height: 24),

                // Live count row — pulled from real Firestore data.
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService().getMothers(),
                  builder: (context, snapshot) {
                    final total = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatTile(label: 'Total mothers', value: '$total', color: AshaColors.ink),
                        ),
                        const SizedBox(width: 10),
                        // NOTE: riskLevel isn't saved on the mother document
                        // yet (BACKEND INTEGRATION REQUIRED FROM USWA —
                        // createMother() needs a riskLevel field), so these
                        // three stay static until that's added.
                        Expanded(child: _StatTile(label: 'Low', value: '—', color: RiskColors.low)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(label: 'Moderate', value: '—', color: RiskColors.moderate)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(label: 'High', value: '—', color: RiskColors.high)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register-mother');
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: const Text('Register mother'),
                ),
                const SizedBox(height: 28),

                Text('TEST123 Needs attention today', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),

                // Now shows REAL registered mothers, most recently added
                // first, tappable into their real profile. Reason text is
                // generic until riskLevel exists on the mother document.
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService().getMothers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Could not load mothers',
                        style: GoogleFonts.inter(color: AshaColors.inkMuted),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Text(
                        'No mothers registered yet',
                        style: GoogleFonts.inter(color: AshaColors.inkMuted),
                      );
                    }
                    final visible = docs.take(3).toList();
                    return Column(
                      children: visible.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Unknown';
                        final pregnancyWeek = data['pregnancyWeek'] as int? ?? 0;
                        final userId = data['userId'] as String? ?? doc.id;

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

                        return _AttentionCard(
                          mother: mother,
                          reason: '$pregnancyWeek weeks • Needs a check-in',
                          onTap: () {
                            Navigator.pushNamed(context, '/mother-profile', arguments: mother);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 28),

                Text('Tools', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                _ToolRow(
                  icon: Icons.favorite_border,
                  label: 'Health check',
                  onTap: () {
                    Navigator.pushNamed(context, '/mothers-list');
                  },
                ),
                _ToolRow(icon: Icons.calendar_month_outlined, label: 'ANC schedule', onTap: () {}),
                _ToolRow(
                  icon: Icons.groups_outlined,
                  label: 'My mothers',
                  onTap: () {
                    Navigator.pushNamed(context, '/mothers-list');
                  },
                ),
                _ToolRow(icon: Icons.emergency_outlined, label: 'Emergency', onTap: () {}, isUrgent: true),
                _ToolRow(icon: Icons.smart_toy_outlined, label: 'Ask AMMA', onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String workerName;
  final bool isOnline;

  const _TopBar({required this.workerName, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final initial = workerName.isNotEmpty ? workerName[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AshaColors.primary.withValues(alpha: 0.12),
          child: Text(
            initial,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.primaryDark, fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workerName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: AshaColors.ink)),
              Text('ASHA Worker', style: GoogleFonts.inter(fontSize: 13, color: AshaColors.inkMuted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? RiskColors.low.withValues(alpha: 0.1) : AshaColors.inkMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 14, color: isOnline ? RiskColors.low : AshaColors.inkMuted),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Synced' : 'Offline',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isOnline ? RiskColors.low : AshaColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AshaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AshaColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: AshaColors.inkMuted)),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final MotherModel mother;
  final String reason;
  final VoidCallback onTap;

  const _AttentionCard({required this.mother, required this.reason, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AshaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AshaColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: AshaColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mother.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AshaColors.ink)),
                  Text(reason, style: GoogleFonts.inter(fontSize: 13, color: AshaColors.inkMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AshaColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isUrgent;

  const _ToolRow({required this.icon, required this.label, required this.onTap, this.isUrgent = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AshaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUrgent ? RiskColors.high.withValues(alpha: 0.3) : AshaColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isUrgent ? RiskColors.high : AshaColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AshaColors.ink))),
            const Icon(Icons.chevron_right, size: 18, color: AshaColors.inkMuted),
          ],
        ),
      ),
    );
  }
}