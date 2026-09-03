import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBd8cHHJB7Rp_nKgzRE-I_iUOomXBdbVcM',
    appId: '1:675538729753:web:987e931bfc021a9e112388',
    messagingSenderId: '675538729753',
    projectId: 'amma-maternal-health',
    authDomain: 'amma-maternal-health.firebaseapp.com',
    storageBucket: 'amma-maternal-health.firebasestorage.app',
  );
}
