import 'package:flutter/material.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/asha/asha_dashboard_screen.dart';
import '../../screens/asha/mothers_list_screen.dart';
import '../../screens/patient/patient_dashboard_screen.dart';
import '../../screens/patient/benefits_screen.dart';
import '../../screens/patient/benefit_detail_screen.dart';
import '../../screens/maternal/register_mother_screen.dart';
import '../../screens/maternal/mother_profile_screen.dart';
import '../../screens/health_check/health_check_screen.dart';
import '../../screens/risk/risk_result_screen.dart';
import '../../models/mother_model.dart';
import '../../models/risk_result.dart';
import '../../data/benefits_data.dart';

class AppRoutes {
  static const String login = '/login';
  static const String ashaDashboard = '/asha-dashboard';
  static const String patientDashboard = '/patient-dashboard';
  static const String registerMother = '/register-mother';
  static const String motherProfile = '/mother-profile';
  static const String mothersList = '/mothers-list';
  static const String healthCheck = '/health-check';
  static const String riskResult = '/risk-result';
  static const String benefits = '/benefits';
  static const String benefitDetail = '/benefit-detail';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginScreen(),
      ashaDashboard: (context) => const AshaDashboardScreen(),
      patientDashboard: (context) => const PatientDashboardScreen(),
      registerMother: (context) => const RegisterMotherScreen(),
      mothersList: (context) => const MothersListScreen(),
      benefits: (context) => const BenefitsScreen(),

      // These routes read the arguments passed via
      // Navigator.pushNamed(..., arguments: ...).
      motherProfile: (context) {
        final mother =
            ModalRoute.of(context)!.settings.arguments as MotherModel?;
        return MotherProfileScreen(mother: mother);
      },
      healthCheck: (context) {
        final mother =
            ModalRoute.of(context)!.settings.arguments as MotherModel;
        return HealthCheckScreen(mother: mother);
      },
      riskResult: (context) {
        final result =
            ModalRoute.of(context)!.settings.arguments as RiskResult;
        return RiskResultScreen(result: result);
      },
      benefitDetail: (context) {
        final scheme =
            ModalRoute.of(context)!.settings.arguments as BenefitScheme;
        return BenefitDetailScreen(scheme: scheme);
      },
    };
  }
}