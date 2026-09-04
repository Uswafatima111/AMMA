import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';

class RiskResultScreen extends StatelessWidget {
  final RiskResult result;

  const RiskResultScreen({super.key, required this.result});

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
            'Health Check Result',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildRiskBadge(),
              const SizedBox(height: 24),
              if (result.matchedRules.isNotEmpty) ...[
                _sectionLabel('Matched Rules'),
                const SizedBox(height: 8),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.matchedRules
                        .map((rule) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.circle, size: 6, color: AshaColors.inkMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rule,
                                      style: GoogleFonts.inter(color: AshaColors.ink, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _sectionLabel('Explanation'),
              const SizedBox(height: 8),
              _buildCard(
                child: Text(
                  result.explanation,
                  style: GoogleFonts.inter(color: AshaColors.ink, fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Recommendation'),
              const SizedBox(height: 8),
              _buildCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medical_services_outlined, color: AshaColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.recommendation,
                        style: GoogleFonts.inter(
                          color: AshaColors.ink,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Rule version: ${result.ruleVersion} • ${_formatTimestamp(result.timestamp)}',
                style: GoogleFonts.inter(color: AshaColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.popUntil(
                    context,
                    (route) => route.isFirst || route.settings.name == '/asha-dashboard',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AshaColors.primary,
                    side: const BorderSide(color: AshaColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back to Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: result.riskLevel.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: result.riskLevel.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(result.riskLevel.icon, color: result.riskLevel.color, size: 40),
          const SizedBox(height: 10),
          Text(
            result.riskLevel.label,
            style: GoogleFonts.inter(color: result.riskLevel.color, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(color: AshaColors.ink, fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AshaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AshaColors.border),
      ),
      child: child,
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}