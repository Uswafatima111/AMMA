import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../models/risk_result.dart';
import '../../services/health_service.dart';

class HealthCheckScreen extends StatefulWidget {
  final MotherModel mother;

  const HealthCheckScreen({super.key, required this.mother});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bpController = TextEditingController();
  final _weightController = TextEditingController();
  final _hemoglobinController = TextEditingController();

  final List<String> _allSymptoms = const [
    'Headache',
    'Swelling',
    'Bleeding',
    'Fever',
  ];
  final Set<String> _selectedSymptoms = {};

  bool _isSubmitting = false;

  @override
  void dispose() {
    _bpController.dispose();
    _weightController.dispose();
    _hemoglobinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final RiskResult result = await HealthService().submitHealthCheck(
      motherId: widget.mother.id,
      gestationalWeeks: widget.mother.gestationalWeeks,
      bloodPressure: _bpController.text.trim(),
      weight: double.parse(_weightController.text.trim()),
      hemoglobin: double.parse(_hemoglobinController.text.trim()),
      symptoms: _selectedSymptoms.toList(),
    );

      if (!mounted) return;

      Navigator.pushNamed(context, '/risk-result', arguments: result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit health check: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
            'Health Check — ${widget.mother.name}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  '${widget.mother.gestationalWeeks} weeks • Assigned to you',
                  style: GoogleFonts.inter(color: AshaColors.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _bpController,
                  label: 'Blood Pressure (e.g. 120/80)',
                  keyboardType: TextInputType.text,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Enter a number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _hemoglobinController,
                  label: 'Hemoglobin (g/dL)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Enter a number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Symptoms',
                  style: GoogleFonts.inter(color: AshaColors.ink, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allSymptoms.map((symptom) {
                    final selected = _selectedSymptoms.contains(symptom);
                    return FilterChip(
                      label: Text(symptom, style: GoogleFonts.inter(fontSize: 13)),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSymptoms.add(symptom);
                          } else {
                            _selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                      selectedColor: AshaColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AshaColors.primaryDark,
                      side: BorderSide(color: AshaColors.border),
                      backgroundColor: AshaColors.surface,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AshaColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Submit Health Check', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: AshaColors.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AshaColors.inkMuted),
        filled: true,
        fillColor: AshaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AshaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AshaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AshaColors.primary, width: 1.5),
        ),
      ),
    );
  }
}