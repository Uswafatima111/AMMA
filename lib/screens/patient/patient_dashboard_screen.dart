import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/lottie_action_tile.dart';

class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  // TODO: BACKEND INTEGRATION REQUIRED FROM USWA
  // Service: MotherService.getMother(currentUserId) -> gestationalWeeks
  // Service: AppointmentService.getUpcomingAppointment(motherId) -> date
  static const int gestationalWeeks = 24;
  static const String nextCheckupDate = '18 SEPT';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      width: 110,
                      child: Lottie.asset(
                        'assets/animations/pregnancy.json',
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.pregnant_woman,
                                size: 80, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$gestationalWeeks',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'WEEKS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
                children: [
                  LottieActionTile(
                    animationAsset: 'assets/animations/calendar.json',
                    fallbackIcon: Icons.calendar_month,
                    label: nextCheckupDate,
                    onTap: () {},
                  ),
                  LottieActionTile(
                    animationAsset: 'assets/animations/heartbeat.json',
                    fallbackIcon: Icons.favorite,
                    label: 'My Health',
                    onTap: () {},
                  ),
                  LottieActionTile(
                    animationAsset: 'assets/animations/bell.json',
                    fallbackIcon: Icons.notifications,
                    label: 'Reminders',
                    onTap: () {},
                  ),
                  LottieActionTile(
                    animationAsset: 'assets/animations/book.json',
                    fallbackIcon: Icons.menu_book,
                    label: 'Guide',
                    onTap: () {},
                  ),
                  LottieActionTile(
                    animationAsset: 'assets/animations/emergency.json',
                    fallbackIcon: Icons.warning_rounded,
                    label: 'Emergency',
                    accentColor: AppColors.riskHigh,
                    onTap: () {},
                  ),
                  LottieActionTile(
                    animationAsset: 'assets/animations/chatbot.json',
                    fallbackIcon: Icons.smart_toy,
                    label: 'Ask AMMA',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}