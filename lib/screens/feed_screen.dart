import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/drop.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../services/onboarding_service.dart';
import '../theme/rm_theme.dart';
import '../widgets/tutorial_overlay.dart';
import 'create_drop_screen.dart';
import 'profile_screen.dart';
import 'drop_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  List<Drop> _drops = [];
  geo.Position? _position;
  bool _loading = true;
  String? _error;
  bool _showTutorial = false;
  StreamSubscription<geo.Position>? _positionSub;
  late AnimationController _fabCtrl;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScale = CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut);
    _initLocation();
    _checkTutorial();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _fabCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkTutorial() async {
    final show = await OnboardingService.instance.shouldShowFeedTutorial();
    if (mounted) setState(() => _showTutorial = show);
  }

  Future<void> _initLocation() async {
    setState(() { _loading = true; _error = null; });
    try {
      final position = await LocationService.instance.getCurrentPosition();
      setState(() => _position = position);
      await _fetchDrops(position);
      _fabCtrl.forward();

      _positionSub = LocationService.instance.watchPosition().listen((pos) {
        setState(() => _position = pos);
        _fetchDrops(pos);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchDrops(geo.Position position) async {
    try {
      final drops = await SupabaseService.instance.fetchNearbyDrops(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) setState(() => _drops = drops);
    } catch (_) {}
  }

  Future<void> _openDrop(Drop drop) async {
    if (_position == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DropDetailScreen(
            drop: drop,
            currentLat: _position!.latitude,
            currentLng: _position!.longitude,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (_position != null) await _fetchDrops(_position!);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: RMColors.background,
          appBar: AppBar(
            backgroundColor: RMColors.background,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Explore'),
                if (_position != null)
                  Text(
                    '${_drops.length} drops nearby',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: RMColors.primary,
            backgroundColor: RMColors.surface,
            onRefresh: _initLocation,
            child: _buildBody(),
          ),
          floatingActionButton: ScaleTransition(
            scale: _fabScale,
            child: FloatingActionButton.extended(
              onPressed: () async {
                if (_position == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateDropScreen(
                      lat: _position!.latitude,
                      lng: _position!.longitude,
                    ),
                  ),
                );
                if (_position != null) await _fetchDrops(_position!);
              },
              backgroundColor: RMColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Drop here'),
            ),
          ),
        ),
        if (_showTutorial)
          TutorialOverlay(
            steps: const [
              TutorialStep(
                icon: Icons.explore_rounded,
                title: 'Welcome to Reality Merge',
                body: 'The world around you is full of hidden content. Walk to locked drops to reveal what people left behind.',
              ),
              TutorialStep(
                icon: Icons.lock_rounded,
                title: 'Locked drops',
                body: 'Drops show how far they are. Get close enough and tap to unlock — the content only reveals when you\'re physically there.',
              ),
              TutorialStep(
                icon: Icons.add_location_alt_rounded,
                title: 'Leave your mark',
                body: 'Tap "Drop here" to pin a photo, video, or message to your exact location. Set it public or private with a specific allowlist.',
              ),
              TutorialStep(
                icon: Icons.map_rounded,
                title: 'See the map',
                body: 'Switch to the Map tab to see all nearby drops on a live satellite view and get walking directions to any of them.',
              ),
            ],
            onDone: () async {
              await OnboardingService.instance.markFeedTutorialSeen();
              if (mounted) setState(() => _showTutorial = false);
            },
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: RMColors.primary),
            SizedBox(height: 16),
            Text('Finding your location…',
                style: TextStyle(color: RMColors.textSecondary)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded,
                  color: RMColors.textHint, size: 48),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RMColors.textSecondary)),
              const SizedBox(height: 20),
              OutlinedButton(
                  onPressed: _initLocation, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_drops.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined,
                      color: RMColors.textHint, size: 48),
                  SizedBox(height: 12),
                  Text('No drops nearby yet.',
                      style: TextStyle(
                          color: RMColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Be the first to leave something here.',
                      style: TextStyle(color: RMColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _drops.length,
      itemBuilder: (context, index) => _AnimatedDropCard(
        drop: _drops[index],
        index: index,
        onTap: () => _openDrop(_drops[index]),
      ),
    );
  }
}

class _AnimatedDropCard extends StatefulWidget {
  final Drop drop;
  final int index;
  final VoidCallback onTap;

  const _AnimatedDropCard({
    required this.drop,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedDropCard> createState() => _AnimatedDropCardState();
}

class _AnimatedDropCardState extends State<_AnimatedDropCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 60),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(
        Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DropCard(drop: widget.drop, onTap: widget.onTap),
        ),
      ),
    );
  }
}

class _DropCard extends StatelessWidget {
  final Drop drop;
  final VoidCallback onTap;

  const _DropCard({required this.drop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = !drop.isUnlocked;
    final canUnlock = drop.isWithinUnlockRange && locked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: RMColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canUnlock
                ? RMColors.accent.withOpacity(0.6)
                : drop.isUnlocked
                    ? RMColors.success.withOpacity(0.3)
                    : RMColors.border,
            width: canUnlock ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: locked
                      ? RMColors.surfaceAlt
                      : RMColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  locked
                      ? (canUnlock
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded)
                      : Icons.lock_open_rounded,
                  color: locked
                      ? (canUnlock ? RMColors.accent : RMColors.textHint)
                      : RMColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked ? 'Locked drop' : (drop.caption ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: locked
                            ? RMColors.textSecondary
                            : RMColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          locked
                              ? Icons.directions_walk_rounded
                              : Icons.person_outline_rounded,
                          size: 12,
                          color: RMColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locked
                              ? drop.distanceLabel
                              : drop.creatorUsername,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (drop.isPrivate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: RMColors.primaryDim,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PRIVATE',
                              style: TextStyle(
                                  color: RMColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canUnlock)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: RMColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: RMColors.accent.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Unlock',
                    style: TextStyle(
                        color: RMColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: RMColors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
