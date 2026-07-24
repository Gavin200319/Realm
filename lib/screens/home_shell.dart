import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/rm_theme.dart';
import 'feed_screen.dart';
import 'chats_screen.dart';
import 'flicks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _lastTabPrefsKey = 'rm_home_shell_last_tab';

  int _currentIndex = 0;
  DateTime? _lastBackPressAt;

  // Keys give us a handle onto each tab's State so we can force a fresh
  // fetch every time that tab is (re)selected — see _onDestinationSelected.
  // An IndexedStack keeps every tab's widget alive in the background, but
  // "alive" isn't the same as "up to date": a tab whose first load raced
  // location/auth and lost, or whose data is just stale from sitting
  // untouched, would otherwise stay that way for the rest of the session
  // even after switching away and back.
  final _feedKey = GlobalKey<FeedScreenState>();
  final _flicksKey = GlobalKey<FlicksScreenState>();

  @override
  void initState() {
    super.initState();
    _restoreLastTab();
  }

  /// Which bottom-nav tab was open last time this app ran — restored
  /// here so a genuine cold start (the process actually got killed,
  /// whether by the OS reclaiming memory or by the back-button fix
  /// below no longer accidentally causing that) drops someone back
  /// where they left off instead of always reopening on Realm.
  Future<void> _restoreLastTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_lastTabPrefsKey);
      if (saved != null && saved >= 0 && saved <= 2 && mounted) {
        setState(() => _currentIndex = saved);
      }
    } catch (_) {
      // Local-storage-only, best-effort — worst case this session
      // just opens on Realm same as before this existed.
    }
  }

  Future<void> _persistLastTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastTabPrefsKey, index);
    } catch (_) {
      // Best-effort — losing this just means the next cold start
      // opens on Realm instead of wherever they actually were.
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    _persistLastTab(index);
    switch (index) {
      case 0:
        _feedKey.currentState?.refresh();
        break;
      case 1:
        _flicksKey.currentState?.refresh();
        break;
    }
  }

  /// System back button, intercepted here rather than left to fall
  /// through to the OS: with nothing else on the navigator stack at
  /// this level, an unhandled back press exits the app outright — a
  /// full process kill, not a pause — which is what made every
  /// "navigate away and come back" feel like a cold boot from
  /// scratch. First back press off the Realm tab returns to Realm
  /// (standard bottom-nav convention); a second press within the
  /// window below actually exits, same as most Android apps with a
  /// bottom nav.
  void _handleBackPress() {
    if (_currentIndex != 0) {
      _onDestinationSelected(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressAt == null ||
        now.difference(_lastBackPressAt!) > const Duration(seconds: 2)) {
      _lastBackPressAt = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithPop: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: RMColors.background,
        body: IndexedStack(
          index: _currentIndex,
          // IndexedStack builds and keeps ALL of these alive simultaneously,
          // not just the visible one — that's what makes the tab-preserving
          // navigation work, but it also means a naive child has no idea
          // whether it's the one currently on screen. FlicksScreen needs
          // that signal explicitly (see isActive) so it knows when it's
          // allowed to actually play video, rather than just going by its
          // own internal notion of "active page" within its feed.
          children: [
            FeedScreen(key: _feedKey),
            FlicksScreen(key: _flicksKey, isActive: _currentIndex == 1),
            ChatsScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: RMColors.border, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: RMColors.surface,
            indicatorColor: RMColors.primaryDim,
            height: 64,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined, color: RMColors.textSecondary),
                selectedIcon: Icon(Icons.explore_rounded, color: RMColors.primary),
                label: 'Realm',
              ),
              NavigationDestination(
                icon: Icon(Icons.movie_creation_outlined,
                    color: RMColors.textSecondary),
                selectedIcon:
                    Icon(Icons.movie_creation_rounded, color: RMColors.primary),
                label: 'Flicks',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    color: RMColors.textSecondary),
                selectedIcon:
                    Icon(Icons.chat_bubble_rounded, color: RMColors.primary),
                label: 'Chats',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
