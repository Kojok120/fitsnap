// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ★ ここで名前とオプションをログ出力
  //    → flutter run / Xcode / Android Studio どのコンソールでも表示される
  debugPrint('✅ FirebaseApp initialized: ${app.name}');

  runApp(const ProviderScope(child: FitSnapApp()));
}

class FitSnapApp extends StatelessWidget {
  const FitSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitSnap',
      home: const Scaffold(
        body: Center(child: Text('Hello, FitSnap!')),
      ),
    );
  }
}