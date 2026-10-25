import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/benefits_data.dart';

class BenefitsScreen extends StatelessWidget {
  const BenefitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Help from the government',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: kBenefitSchemes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final scheme = kBenefitSchemes[index];
          return InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              '/benefit-detail',
              arguments: scheme,
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.color.withValues(alpha: 0.12),
                    child: Icon(scheme.icon, size: 30, color: scheme.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scheme.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheme.summary,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusChip(status: scheme.status),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icon + label (never colour alone) so the meaning survives for everyone.
class _StatusChip extends StatelessWidget {
  final BenefitStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final confirmed = status == BenefitStatus.confirmed;
    final color = confirmed ? AppColors.textSecondary : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          confirmed ? Icons.verified_outlined : Icons.support_agent,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          confirmed ? 'Official' : 'Ask your ASHA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}