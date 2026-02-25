import 'package:flutter/material.dart';

import '../../services/theme_service.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  void _openSignIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _openSignUp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Theme',
                    onPressed: () async {
                      final current = ThemeService.instance.themeMode;
                      final next = current == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light;
                      await ThemeService.instance.setThemeMode(next);
                    },
                    icon: const Icon(Icons.palette_outlined),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.menu_book_rounded,
                size: 78,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'MyDiary',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in to sync your notes across devices and keep them backed up.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _openSignIn(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openSignUp(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Sign Up'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
