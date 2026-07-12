import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'feed_screen.dart';

/// Routes to the login flow or the main feed depending on auth state,
/// and keeps listening so sign-in/sign-out immediately re-routes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.instance.authStateChanges,
      builder: (context, snapshot) {
        final session = SupabaseService.instance.currentUser;
        if (session != null) {
          return const FeedScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
