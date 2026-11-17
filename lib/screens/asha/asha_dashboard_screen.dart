import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mother_mapper.dart';
import '../../models/mother_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/dev_switch_button.dart';

class AshaDashboardScreen extends StatelessWidget {
  const AshaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // CHANGED: in debug builds, fall back to a placeholder id so the
    // dashboard opens even when nobody is signed in (dev switch button).
    final uid = AuthService().currentUser?.uid ??
        (kDebugMode ? 'dev-preview' : null);

    return Theme(
      data: AppTheme.ashaTheme,
      child: Scaffold(
        backgroundColor: AshaColors.background,
        floatingActionButton: const DevSwitchButton(
          targetRoute: '/patient-dashboard',
          label: 'DEV: switch to patient',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: SafeArea(
          child: uid == null
              ? Center(
                  child: Text('Please log in again',
                      style: GoogleFonts.inter(color: AshaColors.inkMuted)),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().getMothersAssignedToAsha(uid),
                  builder: (context, snapshot) {
                    final mothers = snapshot.data == null
                        ? <MotherModel>[]
                        : snapshot.data!.docs
                            .map((d) =>
                                MotherMapper.fromMap(d.data(), id: d.id))
                            .toList();
                    final fromCache =
                        snapshot.data?.metadata.isFromCache ?? true;

                    int count(RiskLevel l) =>
                        mothers.where((m) => m.riskLevel == l).length;

                    // Highest risk first, only mothers who are not low risk.
                    final attention = mothers
                        .where((m) => m.riskLevel != RiskLevel.low)
                        .toList()
                      ..sort((a, b) =>
                          b.riskLevel.index.compareTo(a.riskLevel.index));

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopBar(uid: uid, offline: fromCache),
                          const SizedBox(height: 24),
                          if (snapshot.hasError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Could not load mothers: ${snapshot.error}',
                                style: GoogleFonts.inter(
                                    color: RiskColors.high, fontSize: 13),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: 'Total mothers',
                                  value: '${mothers.length}',
                                  color: AshaColors.ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  label: 'Low',
                                  value: '${count(RiskLevel.low)}',
                                  color: RiskColors.low,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  label: 'Moderate',
                                  value: '${count(RiskLevel.moderate)}',
                                  color: RiskColors.moderate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  label: 'High',
                                  value: '${count(RiskLevel.high)}',
                                  color: RiskColors.high,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                                context, '/register-mother'),
                            icon:
                                const Icon(Icons.person_add_alt_1, size: 20),
                            label: const Text('Register mother'),
                          ),
                          const SizedBox(height: 28),
                          Text('Needs attention today',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          if (attention.isEmpty)
                            Text(
                              mothers.isEmpty
                                  ? 'No mothers registered yet'
                                  : 'No mothers need attention right now',
                              style: GoogleFonts.inter(
                                  color: AshaColors.inkMuted),
                            )
                          else
                            ...attention.take(3).map(
                                  (m) => _AttentionCard(
                                    mother: m,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/mother-profile',
                                      arguments: m,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 28),
                          Text('Tools',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          _ToolRow(
                            icon: Icons.favorite_border,
                            label: 'Health check',
                            onTap: () =>
                                Navigator.pushNamed(context, '/mothers-list'),
                          ),
                          _ToolRow(
                            icon: Icons.groups_outlined,
                            label: 'My mothers',
                            onTap: () =>
                                Navigator.pushNamed(context, '/mothers-list'),
                          ),
                          _ToolRow(
                            icon: Icons.calendar_month_outlined,
                            label: 'ANC schedule',
                            onTap: () => _soon(context),
                          ),
                          _ToolRow(
                            icon: Icons.emergency_outlined,
                            label: 'Emergency',
                            onTap: () => _soon(context),
                            isUrgent: true,
                          ),
                          _ToolRow(
                            icon: Icons.smart_toy_outlined,
                            label: 'Ask AMMA',
                            onTap: () =>
                                Navigator.pushNamed(context, '/amma-chat'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

void _soon(BuildContext context) {
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Coming soon')));
}

Future<void> _logout(BuildContext context) async {
  await AuthService().signOut();
  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}

class _TopBar extends StatelessWidget {
  final String uid;
  final bool offline;

  const _TopBar({required this.uid, required this.offline});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService().getUserProfile(uid),
      builder: (context, snapshot) {
        final name = (snapshot.data?['name'] ?? 'ASHA').toString();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AshaColors.primary.withValues(alpha: 0.12),
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AshaColors.primaryDark,
                  fontSize: 18,
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
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AshaColors.ink,
                    ),
                  ),
                  Text('ASHA Worker',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AshaColors.inkMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: offline
                    ? AshaColors.inkMuted.withValues(alpha: 0.1)
                    : RiskColors.low.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    offline
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    size: 14,
                    color: offline ? AshaColors.inkMuted : RiskColors.low,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offline ? 'Offline' : 'Synced',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: offline ? AshaColors.inkMuted : RiskColors.low,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout, color: AshaColors.inkMuted),
              onPressed: () => _logout(context),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile(
      {required this.label, required this.value, required this.color});

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
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(fontSize: 11, color: AshaColors.inkMuted)),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final MotherModel mother;
  final VoidCallback onTap;

  const _AttentionCard({required this.mother, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final risk = mother.riskLevel;
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
            Icon(risk.icon, color: risk.color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mother.name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, color: AshaColors.ink)),
                  Text(
                    '${risk.label} • ${mother.gestationalWeeks} weeks',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AshaColors.inkMuted),
                  ),
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

  const _ToolRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isUrgent = false,
  });

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
          border: Border.all(
            color: isUrgent
                ? RiskColors.high.withValues(alpha: 0.3)
                : AshaColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isUrgent ? RiskColors.high : AshaColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, color: AshaColors.ink)),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AshaColors.inkMuted),
          ],
        ),
      ),
    );
  }
}