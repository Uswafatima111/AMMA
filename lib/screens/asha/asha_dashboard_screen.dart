import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../core/constants/app_enums.dart';
import '../../services/local_mother_store.dart';

class AshaDashboardScreen extends StatefulWidget {
  const AshaDashboardScreen({super.key});

  static const String workerName = 'Kavya';
  static const bool isOnline = true;

  @override
  State<AshaDashboardScreen> createState() => _AshaDashboardScreenState();
}

class _AshaDashboardScreenState extends State<AshaDashboardScreen> {
  List<MotherModel> get _mothers => LocalMotherStore.instance.mothers;

  @override
  Widget build(BuildContext context) {
    final mothers = _mothers;
    final attentionMothers = mothers.where((m) => m.riskLevel != RiskLevel.low).toList();
    final lowCount = mothers.where((m) => m.riskLevel == RiskLevel.low).length;
    final moderateCount = mothers.where((m) => m.riskLevel == RiskLevel.moderate).length;
    final highCount = mothers.where((m) => m.riskLevel == RiskLevel.high).length;

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
                _TopBar(
                  workerName: AshaDashboardScreen.workerName,
                  isOnline: AshaDashboardScreen.isOnline,
                ),

                const SizedBox(height: 24),

                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search mothers by name',
                    hintStyle:
                        GoogleFonts.inter(color: AshaColors.inkMuted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AshaColors.inkMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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
                        value: '$lowCount',
                        color: RiskColors.low,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Moderate',
                        value: '$moderateCount',
                        color: RiskColors.moderate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'High',
                        value: '$highCount',
                        color: RiskColors.high,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/register-mother');
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 20,
                  ),
                  label: const Text('Register mother'),
                ),

                const SizedBox(height: 28),

                Text(
                  'Needs attention today',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium,
                ),

                const SizedBox(height: 12),

                Column(
                  children: attentionMothers.map((mother) {
                    String reason;

                    if (mother.riskLevel == RiskLevel.high) {
                      reason =
                          '${mother.gestationalWeeks} weeks • High risk';
                    } else if (mother.riskLevel ==
                        RiskLevel.moderate) {
                      reason =
                          '${mother.gestationalWeeks} weeks • Follow-up needed';
                    } else {
                      reason =
                          '${mother.gestationalWeeks} weeks • Needs a check-in';
                    }

                    return _AttentionCard(
                      mother: mother,
                      reason: reason,
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          '/mother-profile',
                          arguments: mother,
                        );
                        if (mounted) setState(() {});
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                Text(
                  'Tools',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium,
                ),

                const SizedBox(height: 12),

                _ToolRow(
                  icon: Icons.favorite_border,
                  label: 'Health check',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/mothers-list');
                    if (mounted) setState(() {});
                  },
                ),

                _ToolRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'ANC schedule',
                  onTap: () {},
                ),

                _ToolRow(
                  icon: Icons.groups_outlined,
                  label: 'My mothers',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/mothers-list');
                    if (mounted) setState(() {});
                  },
                ),

                _ToolRow(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency',
                  onTap: () {},
                  isUrgent: true,
                ),

                _ToolRow(
                  icon: Icons.smart_toy_outlined,
                  label: 'Ask AMMA',
                  onTap: () {},
                ),
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

  const _TopBar({
    required this.workerName,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final initial = workerName.isNotEmpty
        ? workerName[0].toUpperCase()
        : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor:
              AshaColors.primary.withValues(alpha: 0.12),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                workerName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AshaColors.ink,
                ),
              ),
              Text(
                'ASHA Worker',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AshaColors.inkMuted,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isOnline
                ? RiskColors.low.withValues(alpha: 0.1)
                : AshaColors.inkMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 14,
                color: isOnline
                    ? RiskColors.low
                    : AshaColors.inkMuted,
              ),

              const SizedBox(width: 4),

              Text(
                isOnline ? 'Synced' : 'Offline',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOnline
                      ? RiskColors.low
                      : AshaColors.inkMuted,
                ),
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

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: AshaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AshaColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AshaColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final MotherModel mother;
  final String reason;
  final VoidCallback onTap;

  const _AttentionCard({
    required this.mother,
    required this.reason,
    required this.onTap,
  });

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
          border: Border.all(
            color: AshaColors.border,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_outline,
              color: AshaColors.primary,
              size: 22,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    mother.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AshaColors.ink,
                    ),
                  ),

                  Text(
                    reason,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AshaColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: AshaColors.inkMuted,
            ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
            Icon(
              icon,
              size: 20,
              color: isUrgent
                  ? RiskColors.high
                  : AshaColors.primary,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: AshaColors.ink,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AshaColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}