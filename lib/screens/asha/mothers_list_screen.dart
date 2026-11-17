import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mother_mapper.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class MothersListScreen extends StatelessWidget {
  const MothersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

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
            'My mothers',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AshaColors.ink),
          ),
          actions: [
            IconButton(
              tooltip: 'Register mother',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () =>
                  Navigator.pushNamed(context, '/register-mother'),
            ),
          ],
        ),
        body: SafeArea(
          child: uid == null
              ? Center(
                  child: Text('Please log in again',
                      style: GoogleFonts.inter(color: AshaColors.inkMuted)),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().getMothersAssignedToAsha(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load mothers.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style:
                                GoogleFonts.inter(color: AshaColors.inkMuted),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = [...snapshot.data!.docs]..sort((a, b) =>
                        (a.data()['name'] ?? '')
                            .toString()
                            .compareTo((b.data()['name'] ?? '').toString()));

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No mothers registered yet',
                                style: GoogleFonts.inter(
                                    color: AshaColors.inkMuted, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pushNamed(
                                    context, '/register-mother'),
                                child: const Text('Register mother'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final mother = MotherMapper.fromMap(
                          docs[index].data(),
                          id: docs[index].id,
                        );
                        final risk = mother.riskLevel;

                        return InkWell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/mother-profile',
                            arguments: mother,
                          ),
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
                                  backgroundColor: AshaColors.primary
                                      .withValues(alpha: 0.12),
                                  child: Text(
                                    mother.name.isNotEmpty
                                        ? mother.name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: AshaColors.primaryDark,
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
                                        mother.name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: AshaColors.ink,
                                        ),
                                      ),
                                      Text(
                                        '${mother.gestationalWeeks} weeks',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AshaColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(risk.icon, size: 18, color: risk.color),
                                const SizedBox(width: 4),
                                Text(
                                  risk.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: risk.color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right,
                                    color: AshaColors.inkMuted),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}