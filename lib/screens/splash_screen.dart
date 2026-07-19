import 'package:flutter/material.dart';
import '../theme/rm_theme.dart';

/// The app's boot screen — shown from the moment Flutter takes over
/// drawing (replacing the plain native launch screen as fast as
/// possible) until env vars, theme/prefs, and Supabase are ready.
///
/// Deliberately simple: brand mark, wordmark, tagline, and a thin
/// animated progress bar. No network calls, no async work of its own —
/// it just renders instantly using [RMColors]' default (dark) palette,
/// which is available immediately even before [ThemeController.init]
/// has run.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RMColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand mark — a soft glowing ring around a location pin,
            // echoing the "world lights up around you" concept without
            // needing a shipped logo asset.
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final glow = 0.35 + (_pulseCtrl.value * 0.25);
                return Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [RMColors.primary, RMColors.primaryDim],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RMColors.primary.withOpacity(glow),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Icon(Icons.travel_explore_rounded,
                  color: Colors.white, size: 46),
            ),
            SizedBox(height: 28),
            Text(
              'REALITY MERGE',
              style: TextStyle(
                color: RMColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The world is no longer empty.',
              style: TextStyle(color: RMColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 56),
            _BrandProgressBar(),
          ],
        ),
      ),
    );
  }
}

/// A slim, rounded, indeterminate progress bar in the app's primary
/// color — deliberately not tied to a real "percent loaded" number
/// (boot work like reading a couple of prefs and opening a Supabase
/// client doesn't have a meaningful progress fraction), just a clear
/// "something's happening" signal in the app's own visual language.
class _BrandProgressBar extends StatelessWidget {
  const _BrandProgressBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          minHeight: 5,
          backgroundColor: RMColors.surfaceAlt,
          valueColor: AlwaysStoppedAnimation(RMColors.primary),
        ),
      ),
    );
  }
}

/// Shown instead of the splash if boot actually fails (e.g. missing
/// `.env`, unreachable Supabase project) — same visual language, but
/// with a message and a way to try again rather than being stuck on
/// an indeterminate bar forever.
class SplashErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const SplashErrorScreen(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RMColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, color: RMColors.danger, size: 44),
              SizedBox(height: 16),
              Text(
                'Couldn\'t start Reality Merge',
                style: TextStyle(
                    color: RMColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: RMColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              OutlinedButton(onPressed: onRetry, child: Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
