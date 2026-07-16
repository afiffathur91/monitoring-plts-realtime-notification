import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/solar_provider.dart';
import 'providers/device_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/local_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inisialisasi notifikasi pop-up di HP (untuk peringatan batas ambang)
  await LocalNotificationService().initialize();

  // Inisialisasi Firebase Messaging
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Pesan notifikasi diterima: ${message.notification?.title} - ${message.notification?.body}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SolarProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Initialize auth provider
          if (!authProvider.isLoading && authProvider.user == null) {
            Future.microtask(() => authProvider.init());
          }
          
          return MaterialApp(
            title: 'PLTS Monitoring',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.grey[50],
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardTheme(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            home: authProvider.isLoading
                ? const _LoadingScreen()
                : authProvider.isAuthenticated
                    ? const DashboardScreen()
                    : const LoginScreen(),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
