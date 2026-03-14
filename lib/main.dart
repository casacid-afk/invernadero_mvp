import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/invernadero_firestore_repo.dart';
import 'domain/motor_invernadero.dart';
import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'navigation_observer.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CL', null);
  Intl.defaultLocale = 'es_CL';
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invernadero MVP',
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      home: HomeShell(
        motor: MotorInvernadero(),
        firestoreRepo: InvernaderoFirestoreRepo(),
      ),
    );
  }
}
