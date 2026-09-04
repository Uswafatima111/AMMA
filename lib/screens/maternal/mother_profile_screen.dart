import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_enums.dart';
import '../../models/mother_model.dart';

class MotherProfileScreen extends StatelessWidget {
  final MotherModel mother;

  // TODO: BACKEND INTEGRATION REQUIRED FROM USWA
  // Service: MotherService.getMother(motherId) -> MotherModel
  // Service: HealthService.getHealthRecords(motherId) -> latest record
  // Until that exists, falls back to mock data if no MotherModel is passed in.
  MotherProfileScreen({super.key, MotherModel? mother}) : mother = mother ?? _mockMother;

  static final MotherModel _mockMother = MotherModel(
    id: 'mock-amina-01',
    name: 'Amina',
    age: 26,
    phone: '9876543210',
    gestationalWeeks: 24,
    bloodPressure: '118/76',
    weight: 54,
    hemoglobin: 11.2,
    symptoms: const [],
    emergencyContact: '9876500000',
    riskLevel: RiskLevel.low,
    assignedAshaId: 'mock-asha-01',
    createdAt: DateTime.now(),
  );

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
            mother.name,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Header: avatar + weeks + risk badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AshaColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AshaColors.border),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AshaColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        mother.name.isNotEmpty ? mother.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AshaColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${mother.gestationalWeeks} weeks',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AshaColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: mother.riskLevel.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(mother.riskLevel.icon, size: 16, color: mother.riskLevel.color),
                          const SizedBox(width: 6),
                          Text(
                            mother.riskLevel.label,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: mother.riskLevel.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Latest vitals', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _VitalTile(
                      icon: Icons.favorite_outline,
                      label: 'Blood pressure',
                      value: mother.bloodPressure,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VitalTile(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      value: '${mother.weight} kg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VitalTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Hemoglobin',
                      value: '${mother.hemoglobin}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _ToolRow(
                icon: Icons.favorite_border,
                label: 'Health check',
                onTap: () {
                  Navigator.pushNamed(context, '/health-check', arguments: mother);
                },
              ),
              _ToolRow(icon: Icons.calendar_month_outlined, label: 'Next ANC', onTap: () {}),
              _ToolRow(
                icon: Icons.emergency_outlined,
                label: 'Emergency',
                onTap: () {},
                isUrgent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VitalTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AshaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AshaColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AshaColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AshaColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AshaColors.inkMuted),
          ),
        ],
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
            color: isUrgent ? RiskColors.high.withValues(alpha: 0.3) : AshaColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isUrgent ? RiskColors.high : AshaColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AshaColors.ink),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AshaColors.inkMuted),
          ],
        ),
      ),
    );
  }
}