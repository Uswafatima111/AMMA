import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/health_record_service.dart';
import '../../services/health_service.dart';

class RegisterMotherScreen extends StatefulWidget {
  const RegisterMotherScreen({super.key});

  @override
  State<RegisterMotherScreen> createState() => _RegisterMotherScreenState();
}

class _RegisterMotherScreenState extends State<RegisterMotherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _weeksController = TextEditingController();
  final _bpController = TextEditingController();
  final _weightController = TextEditingController();
  final _hemoglobinController = TextEditingController();
  final _emergencyController = TextEditingController();

  final Set<String> _selectedSymptoms = {};
  static const List<String> _symptomOptions = [
    'Headache',
    'Swelling',
    'Bleeding',
    'Fever',
  ];

  bool _isSaving = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final ashaUid = AuthService().currentUser?.uid;
    if (ashaUid == null) {
      _snack('Please log in again');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final weeks = int.parse(_weeksController.text.trim());
      final bp = _bpController.text.trim();
      final weight = double.parse(_weightController.text.trim());
      final hb = double.parse(_hemoglobinController.text.trim());
      final emergency = _emergencyController.text.trim();
      final symptoms = _selectedSymptoms.toList();

      // Uswa's RiskEngine decides the starting risk level.
      final risk = HealthService().assess(
        pregnancyWeek: weeks,
        bloodPressure: bp,
        hemoglobin: hb,
        weight: weight,
        symptoms: symptoms,
      );

      final motherId = await FirestoreService().createMotherProfile(
        name: name,
        age: age,
        phone: phone,
        gestationalWeeks: weeks,
        bloodPressure: bp,
        weight: weight,
        hemoglobin: hb,
        symptoms: symptoms,
        emergencyContact: emergency,
        assignedAshaId: ashaUid,
        riskLevel: risk.riskLevel.name,
      );

      // Save the registration vitals as her first health record.
      await HealthRecordService().addHealthRecord(
        motherId: motherId,
        bloodPressure: bp,
        weight: weight,
        hemoglobin: hb,
        symptoms: symptoms,
        riskLevel: risk.riskLevel.name,
        matchedRules: risk.matchedRules,
        explanation: risk.explanation,
        recommendation: risk.recommendation,
        ruleVersion: risk.ruleVersion,
      );

      if (!mounted) return;

      final mother = MotherModel(
        id: motherId,
        name: name,
        age: age,
        phone: phone,
        gestationalWeeks: weeks,
        bloodPressure: bp,
        weight: weight,
        hemoglobin: hb,
        symptoms: symptoms,
        emergencyContact: emergency,
        riskLevel: risk.riskLevel,
        assignedAshaId: ashaUid,
        createdAt: DateTime.now(),
      );

      _snack('$name registered');
      Navigator.pushReplacementNamed(context, '/mother-profile',
          arguments: mother);
    } on ArgumentError catch (e) {
      _snack('${e.message}');
    } catch (_) {
      _snack('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _weeksController.dispose();
    _bpController.dispose();
    _weightController.dispose();
    _hemoglobinController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _intInRange(String? v, int min, int max) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < min || n > max) return 'Enter $min to $max';
    return null;
  }

  String? _positiveNumber(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null || n <= 0) return 'Enter a number';
    return null;
  }

  String? _bloodPressure(String? v) {
    final ok = RegExp(r'^\d{2,3}\s*/\s*\d{2,3}$').hasMatch((v ?? '').trim());
    return ok ? null : 'Use the form 120/80';
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
          title: Text(
            'Register mother',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
          iconTheme: const IconThemeData(color: AshaColors.ink),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const _SectionLabel('Basic details'),
                _AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  validator: _required,
                ),
                _AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _ageController,
                        label: 'Age',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => _intInRange(v, 1, 120),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _weeksController,
                        label: 'Weeks pregnant',
                        icon: Icons.pregnant_woman_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => _intInRange(v, 1, 42),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _SectionLabel('Vitals'),
                _AppTextField(
                  controller: _bpController,
                  label: 'Blood pressure (e.g. 118/76)',
                  icon: Icons.favorite_outline,
                  validator: _bloodPressure,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _weightController,
                        label: 'Weight (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: _positiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _hemoglobinController,
                        label: 'Hemoglobin (g/dL)',
                        icon: Icons.water_drop_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _SectionLabel('Symptoms'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _symptomOptions.map((symptom) {
                    final selected = _selectedSymptoms.contains(symptom);
                    return FilterChip(
                      label: Text(symptom),
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
                      selectedColor:
                          AshaColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AshaColors.primaryDark,
                      labelStyle: GoogleFonts.inter(
                        color: selected
                            ? AshaColors.primaryDark
                            : AshaColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: AshaColors.surface,
                      side: BorderSide(
                        color:
                            selected ? AshaColors.primary : AshaColors.border,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Emergency contact'),
                _AppTextField(
                  controller: _emergencyController,
                  label: 'Emergency contact number',
                  icon: Icons.contact_phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save mother'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AshaColors.inkMuted,
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(color: AshaColors.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.inter(color: AshaColors.inkMuted, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: AshaColors.inkMuted),
        ),
      ),
    );
  }
}