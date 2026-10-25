import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../services/local_mother_store.dart';

class MothersListScreen extends StatelessWidget {
  const MothersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mothers = LocalMotherStore.instance.mothers;

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
            'My Mothers',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
        ),
        body: SafeArea(
          child: mothers.isEmpty
              ? Center(
                  child: Text(
                    'No mothers registered yet',
                    style: GoogleFonts.inter(color: AshaColors.inkMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: mothers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final mother = mothers[index];

                    return InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/mother-profile', arguments: mother);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AshaColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AshaColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AshaColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                mother.name.isNotEmpty ? mother.name[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: AshaColors.primaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mother.name,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AshaColors.ink),
                                  ),
                                  Text(
                                    '${mother.gestationalWeeks} weeks',
                                    style: GoogleFonts.inter(fontSize: 12, color: AshaColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AshaColors.inkMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}