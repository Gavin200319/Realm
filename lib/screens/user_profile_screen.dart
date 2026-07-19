import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/drop.dart';
import '../models/profile_stats.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../theme/rm_theme.dart';
import '../widgets/drop_card.dart';
import 'drop_detail_screen.dart';

/// Read-only view of someone else's profile, reached by searching their
/// username from the Explore feed. Lists every drop they've made —
/// locked ones included, each showing its distance — since the Explore
/// feed itself only shows already-unlocked drops. This is the intended
/// way to find a specific locked drop: look up who left it.
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;
  /// Passed down from the feed when already known, so this screen
  /// doesn't have to wait on a fresh GPS fix if one's already in hand.
  final double? currentLat;
  final double? currentLng;

  UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    this.currentLat,
    this.currentLng,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  ProfileStats? _stats;
  List<Drop> _drops = [];
  double? _lat;
  double? _lng;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lat = widget.currentLat;
    _lng = widget.currentLng;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_lat == null || _lng == null) {
        final position = await LocationService.instance.getCurrentPosition();
        _lat = position.latitude;
        _lng = position.longitude;
      }
      final results = await Future.wait([
        SupabaseService.instance.fetchProfileStats(widget.userId),
        SupabaseService.instance.fetchUserDrops(
          userId: widget.userId,
          lat: _lat!,
          lng: _lng!,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as ProfileStats?;
        _drops = results[1] as List<Drop>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDrop(Drop drop) async {
    if (_lat == null || _lng == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          drop: drop,
          currentLat: _lat!,
          currentLng: _lng!,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RMColors.background,
      appBar: AppBar(
        backgroundColor: RMColors.background,
        title: Text('@${widget.username}'),
      ),
      body: RefreshIndicator(
        color: RMColors.primary,
        backgroundColor: RMColors.surface,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: RMColors.primary));
    }
    if (_error != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RMColors.textSecondary)),
                    SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: Text('Try again')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: RMColors.primaryDim,
              backgroundImage: _stats?.avatarUrl != null
                  ? CachedNetworkImageProvider(_stats!.avatarUrl!)
                  : null,
              child: _stats?.avatarUrl == null
                  ? Icon(Icons.person_rounded, color: RMColors.primary, size: 30)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${widget.username}',
                      style: TextStyle(
                          color: RMColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      _StatChip(
                          label: 'drops',
                          value: _stats?.dropsCreated ?? _drops.length),
                      SizedBox(width: 8),
                      _StatChip(
                          label: 'unlocked',
                          value: _stats?.dropsUnlocked ?? 0),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Text('Drops',
            style: TextStyle(
                color: RMColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        SizedBox(height: 12),
        if (_drops.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No drops from this user yet.',
                  style: TextStyle(color: RMColors.textSecondary)),
            ),
          )
        else
          ..._drops.map((drop) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: DropCard(drop: drop, onTap: () => _openDrop(drop)),
              )),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RMColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RMColors.border),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
            color: RMColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
