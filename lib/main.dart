import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.initDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandPrimary = Color(0xFF1B6E6A);
    const brandSecondary = Color(0xFFFFB13D);
    const canvas = Color(0xFFF7F4EF);
    const surface = Color(0xFFFFFEFB);

    return MaterialApp(
      title: 'Notepad Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandPrimary,
          secondary: brandSecondary,
          surface: surface,
          background: canvas,
        ),
        scaffoldBackgroundColor: canvas,
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.dmSerifDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
