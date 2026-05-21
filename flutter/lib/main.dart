import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/result_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiService(),
      child: const VetVoiceApp(),
    ),
  );
}

class VetVoiceApp extends StatelessWidget {
  const VetVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetVoice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/result': (context) => const ResultScreen(),
      },
    );
  }
}
