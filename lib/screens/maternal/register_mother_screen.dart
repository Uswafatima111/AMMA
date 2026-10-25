import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mother_model.dart';
import '../../core/constants/app_enums.dart';
import '../../services/firestore_service.dart';
import '../../services/local_mother_store.dart';

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
  final _gestationalWeeksController = TextEditingController();
  final _bpController = TextEditingController();
  final _weightController = TextEditingController();
  final _hemoglobinController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  final Set<String> _selectedSymptoms = {};
  static const List<String> _symptomOptions = [
    'Headache',
    'Swelling',
    'Bleeding',
    'Fever',
  ];

  bool _isSaving = false;

  Future<void> _handleSave() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSaving = true);

  final userId = DateTime.now().millisecondsSinceEpoch.toString(); // TODO: replace once Uswa confirms real ID strategy (auto-ID vs matching auth uid)

  // Try to save to Firestore, but don't let a failure block registration —
  // TEMPORARY while Firebase isn't running locally. Revert once Firebase
  // is confirmed working so a failed save is surfaced to the user again.
  try {
    await FirestoreService().createMother(
      userId: userId,
      name: _nameController.text.trim(),
      pregnancyWeek: int.tryParse(_gestationalWeeksController.text.trim()) ?? 0,
      status: 'active', // TODO: confirm what values `status` expects with Uswa
    );
  } catch (_) {
    // Firebase not available right now — continue locally.
  }

  // BACKEND INTEGRATION REQUIRED FROM USWA — vitals below have no home yet:
  // age, phone, bloodPressure, weight, hemoglobin, symptoms, emergencyContact
  // are collected here but NOT saved anywhere until createMother() is
  // expanded, or we're told to route them through addHealthRecord() instead.

  if (!mounted) return;

  final newMother = MotherModel(
    id: userId,
    name: _nameController.text.trim(),
    age: int.tryParse(_ageController.text.trim()) ?? 0,
    phone: _phoneController.text.trim(),
    gestationalWeeks: int.tryParse(_gestationalWeeksController.text.trim()) ?? 0,
    bloodPressure: _bpController.text.trim(),
    weight: double.tryParse(_weightController.text.trim()) ?? 0,
    hemoglobin: double.tryParse(_hemoglobinController.text.trim()) ?? 0,
    symptoms: _selectedSymptoms.toList(),
    emergencyContact: _emergencyContactController.text.trim(),
    riskLevel: RiskLevel.low,
    assignedAshaId: 'mock-asha-01',
    createdAt: DateTime.now(),
  );
  LocalMotherStore.instance.addMother(newMother);
  Navigator.pushReplacementNamed(context, '/mother-profile', arguments: newMother);

  if (mounted) setState(() => _isSaving = false);
}

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _gestationalWeeksController.dispose();
    _bpController.dispose();
    _weightController.dispose();
    _hemoglobinController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
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
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
          iconTheme: const IconThemeData(color: AshaColors.ink),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _SectionLabel('Basic details'),
                _AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                _AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _ageController,
                        label: 'Age',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _gestationalWeeksController,
                        label: 'Gestational weeks',
                        icon: Icons.pregnant_woman_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SectionLabel('Vitals'),
                _AppTextField(
                  controller: _bpController,
                  label: 'Blood pressure (e.g. 118/76)',
                  icon: Icons.favorite_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _weightController,
                        label: 'Weight (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _hemoglobinController,
                        label: 'Hemoglobin',
                        icon: Icons.water_drop_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SectionLabel('Symptoms'),
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
                      selectedColor: AshaColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AshaColors.primaryDark,
                      labelStyle: GoogleFonts.inter(
                        color: selected ? AshaColors.primaryDark : AshaColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: AshaColors.surface,
                      side: BorderSide(
                        color: selected ? AshaColors.primary : AshaColors.border,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Emergency contact'),
                _AppTextField(
                  controller: _emergencyContactController,
                  label: 'Emergency contact number',
                  icon: Icons.contact_phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          labelStyle: GoogleFonts.inter(color: AshaColors.inkMuted, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: AshaColors.inkMuted),
        ),
      ),
    );
  }
}