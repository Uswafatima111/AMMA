import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/benefits_data.dart';

class BenefitDetailScreen extends StatelessWidget {
  final BenefitScheme scheme;

  const BenefitDetailScreen({super.key, required this.scheme});

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the website')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the website')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: scheme.color.withValues(alpha: 0.12),
                child: Icon(scheme.icon, size: 40, color: scheme.color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              scheme.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scheme.summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            if (scheme.status == BenefitStatus.checkWithAsha)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Details may have changed. Please confirm with your ASHA or Anganwadi worker before you go.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const _SectionTitle('What you get'),
            ...scheme.whatYouGet.map(
              (t) => _IconLine(
                icon: Icons.check_circle_outline,
                color: scheme.color,
                text: t,
              ),
            ),

            const _SectionTitle('Who can get it'),
            Text(
              scheme.whoCanGet,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),

            const _SectionTitle('How to get it'),
            ...List.generate(
              scheme.howToGet.length,
              (i) => _StepLine(
                number: i + 1,
                color: scheme.color,
                text: scheme.howToGet[i],
              ),
            ),

            if (scheme.documents.isNotEmpty) ...[
              const _SectionTitle('Keep these ready'),
              ...scheme.documents.map(
                (t) => _IconLine(
                  icon: Icons.description_outlined,
                  color: AppColors.textSecondary,
                  text: t,
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: BACKEND INTEGRATION REQUIRED FROM USWA
                // Create a help request the ASHA can see (e.g. alerts
                // document, type 'benefit_help', with motherId + scheme.id).
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Asking your ASHA for help is coming soon'),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Ask my ASHA to help'),
            ),
            if (scheme.officialUrl != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openUrl(context, scheme.officialUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Official website'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Source: ${scheme.source} • ${scheme.lastVerified}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _IconLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final int number;
  final Color color;
  final String text;

  const _StepLine({
    required this.number,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}