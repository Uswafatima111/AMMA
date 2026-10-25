import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart' show RiskColors;
import '../../core/theme/patient_palette.dart';
import '../../core/utils/pregnancy_utils.dart';
import '../../widgets/video_slot.dart';

class _VideoEntry {
  final String title;
  final String? url;
  const _VideoEntry(this.title, [this.url]);
}

class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  // MOCK DATA. TODO: BACKEND INTEGRATION REQUIRED FROM USWA
  //  - mothers: gestationalWeeks, expectedDeliveryDate, assignedAshaId
  //  - ASHA contact: the ASHA's phone number (not in the contract yet)
  //  - appointments: date + doctorName + facilityName (doctor fields missing)
  static const int gestationalWeeks = 24;
  static const String ashaPhone = '9876500000';
  static const String doctorName = 'Dr. Lakshmi';
  static const String clinicName = 'Government health centre';
  static const int appointmentInDays = 9;

  // Video titles are placeholders. Add a url when a video is ready.
  static const List<_VideoEntry> _duringPregnancy = [
    _VideoEntry('Eating well'),
    _VideoEntry('Iron tablets'),
    _VideoEntry('Rest and sleep'),
    _VideoEntry('Warning signs: go to hospital'),
  ];
  static const List<_VideoEntry> _afterDelivery = [
    _VideoEntry('Feeding your baby'),
    _VideoEntry('Caring for yourself'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatientPalette.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _HeroHeader(
            weeks: gestationalWeeks,
            ashaPhone: ashaPhone,
            doctorName: doctorName,
            clinicName: clinicName,
            appointmentInDays: appointmentInDays,
          ),
          if (PregnancyUtils.isNearTerm(gestationalWeeks))
            const _NearTermBanner(),
          const _EmergencyStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Free food, check-ups and delivery'),
                const VideoSlot(title: 'What the government gives you'),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/benefits'),
                    child: Text(
                      'See all schemes  ›',
                      style: GoogleFonts.inter(
                        color: PatientPalette.navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const _SectionTitle('During pregnancy'),
                ..._duringPregnancy.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: VideoSlot(title: v.title, videoUrl: v.url),
                  ),
                ),
                const _SectionTitle('After delivery'),
                ..._afterDelivery.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: VideoSlot(title: v.title, videoUrl: v.url),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _dial(BuildContext context, String number) async {
  try {
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone')),
      );
    }
  }
}

class _HeroHeader extends StatelessWidget {
  final int weeks;
  final String ashaPhone;
  final String doctorName;
  final String clinicName;
  final int appointmentInDays;

  const _HeroHeader({
    required this.weeks,
    required this.ashaPhone,
    required this.doctorName,
    required this.clinicName,
    required this.appointmentInDays,
  });

  @override
  Widget build(BuildContext context) {
    final due = PregnancyUtils.estimatedDueDate(weeks);
    final left = PregnancyUtils.weeksLeft(weeks);
    final trimester = PregnancyUtils.trimesterOf(weeks);
    final ordinal = const ['1st', '2nd', '3rd'][trimester - 1];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PatientPalette.navyDeep, PatientPalette.navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            children: [
              // Top row: name + Contact ASHA (top right)
              Row(
                children: [
                  Text(
                    'AMMA',
                    style: GoogleFonts.lora(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _dial(context, ashaPhone),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: PatientPalette.gold,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Contact ASHA',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Baby progress: ring + weeks to go
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: weeks / PregnancyUtils.fullTermWeeks,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                                PatientPalette.gold),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$weeks',
                              style: GoogleFonts.lora(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                            Text(
                              'WEEKS',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$left weeks to go',
                          style: GoogleFonts.lora(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Baby due about\n${due.day} ${PregnancyUtils.monthName(due)} ${due.year}',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _TrimesterBar(weeks: weeks, currentLabel: ordinal),
              const SizedBox(height: 20),

              // Next appointment
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: PatientPalette.goldSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${DateTime.now().add(Duration(days: appointmentInDays)).day}',
                            style: GoogleFonts.lora(
                              color: PatientPalette.navy,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PregnancyUtils.monthName(DateTime.now()
                                .add(Duration(days: appointmentInDays)))
                                .toUpperCase(),
                            style: GoogleFonts.inter(
                              color: PatientPalette.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next check-up',
                            style: GoogleFonts.inter(
                              color: PatientPalette.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'in $appointmentInDays days',
                            style: GoogleFonts.lora(
                              color: PatientPalette.ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$doctorName • $clinicName',
                            style: GoogleFonts.inter(
                              color: PatientPalette.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three segments: 1st, 2nd, 3rd trimester, filling up as weeks pass.
class _TrimesterBar extends StatelessWidget {
  final int weeks;
  final String currentLabel;

  const _TrimesterBar({required this.weeks, required this.currentLabel});

  // (start week, length in weeks) for each trimester
  static const List<List<int>> _segments = [
    [0, 13],
    [13, 14],
    [27, 13],
  ];

  @override
  Widget build(BuildContext context) {
    const labels = ['1st', '2nd', '3rd'];
    final current = PregnancyUtils.trimesterOf(weeks) - 1;

    return Row(
      children: List.generate(3, (i) {
        final start = _segments[i][0];
        final length = _segments[i][1];
        double fraction = (weeks - start) / length;
        if (fraction < 0) fraction = 0;
        if (fraction > 1) fraction = 1;
        final isCurrent = i == current;

        return Expanded(
          flex: length,
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(PatientPalette.gold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCurrent ? '${labels[i]}  • you are here' : labels[i],
                  style: GoogleFonts.inter(
                    color: isCurrent ? PatientPalette.gold : Colors.white60,
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _NearTermBanner extends StatelessWidget {
  const _NearTermBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PatientPalette.goldSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PatientPalette.gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: PatientPalette.navy, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Baby is almost here.\nKeep your hospital bag ready.\nTell your ASHA.',
              style: GoogleFonts.inter(
                color: PatientPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyStrip extends StatelessWidget {
  const _EmergencyStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RiskColors.high.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Emergency?',
              style: GoogleFonts.lora(
                color: PatientPalette.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: () => _dial(context, '108'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: RiskColors.high,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Call 108',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 24, color: PatientPalette.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lora(
                color: PatientPalette.ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}