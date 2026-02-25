import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'database/database_helper.dart';
import 'screens/auth/auth_landing_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await DatabaseHelper.instance.initDatabase();
  await ThemeService.instance.loadThemeMode();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const lightPrimary = Color(0xFF3A9E97);
    const darkPrimary = Color(0xFF7FD8CF);
    const lightSecondary = Color(0xFFEF9F8A);
    const darkSecondary = Color(0xFFFFC0AC);
    const lightTertiary = Color(0xFFD8B85D);
    const darkTertiary = Color(0xFFF0D789);
    const lightCanvas = Color(0xFFF7F7F1);
    const darkCanvas = Color(0xFF121816);
    const lightSurface = Color(0xFFFFFCF7);
    const darkSurface = Color(0xFF1D2623);
    const lightOn = Color(0xFF102220);
    const darkOn = Color(0xFFE7F0EE);
    final rectangularShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? darkPrimary : lightPrimary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? darkPrimary : lightPrimary,
          secondary: isDark ? darkSecondary : lightSecondary,
          tertiary: isDark ? darkTertiary : lightTertiary,
          surface: isDark ? darkSurface : lightSurface,
          onSurface: isDark ? darkOn : lightOn,
        );

    final baseText = GoogleFonts.inconsolataTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkCanvas : lightCanvas,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: baseText.copyWith(
        displayLarge: GoogleFonts.inconsolata(
          fontSize: 46,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        displayMedium: GoogleFonts.inconsolata(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        headlineLarge: GoogleFonts.inconsolata(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inconsolata(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rectangularShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.45,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        disabledColor: scheme.surfaceContainerHighest.withValues(alpha: 0.34),
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        secondarySelectedColor: scheme.secondary.withValues(alpha: 0.22),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: baseText.labelLarge ?? const TextStyle(),
        secondaryLabelStyle: (baseText.labelLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        ),
        brightness: brightness,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: rectangularShape,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: rectangularShape),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: rectangularShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: rectangularShape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: rectangularShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: rectangularShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF23312D) : const Color(0xFF173934),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFFF8FAFC) : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(shape: rectangularShape),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDiary',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeService.instance.themeMode,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthLandingScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
