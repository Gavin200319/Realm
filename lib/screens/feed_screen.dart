import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/drop.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'create_drop_screen.dart';
import 'profile_screen.dart';
import 'drop_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Drop> _drops = [];
  Position? _position;
  bool _loading = true;
  String? _error;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Get an immediate fresh fix first
      final position = await LocationService.instance.getCurrentPosition();
      setState(() => _position = position);
      await _fetchDrops(position);

      // Then stream updates — re-fetches drops every time user moves 5m
      _positionSub = LocationService.instance.watchPosition().listen(
        (pos) async {
          setState(() => _position = pos);
          await _fetchDrops(pos);
        },
        onError: (_) {}, // silently ignore stream errors
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchDrops(Position position) async {
    try {
      final drops = await SupabaseService.instance.fetchNearbyDrops(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) setState(() => _drops = drops);
    } catch (_) {}
  }

  Future<void> _refresh() => _initLocation();

  Future<void> _openDrop(Drop drop) async {
    if (_position == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          drop: drop,
          currentLat: _position!.latitude,
          currentLng: _position!.longitude,
        ),
      ),
    );
    if (_position != null) await _fetchDrops(_position!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nearby Drops'),
            if (_position != null)
              Text(
                'GPS: ${_position!.latitude.toStringAsFixed(5)}, '
                '${_position!.longitude.toStringAsFixed(5)} '
                '± ${_position!.accuracy.round()}m',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Drop here'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Getting your location...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
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
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No Drops nearby yet.\nBe the first to leave one.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _drops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DropCard(
        drop: _drops[index],
        onTap: () => _openDrop(_drops[index]),
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                locked ? Icons.lock_outline : Icons.lock_open,
                color: locked ? Colors.grey : Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked ? 'Locked Drop' : drop.caption ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locked
                          ? const TextStyle(fontStyle: FontStyle.italic)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locked
                          ? drop.distanceLabel
                          : 'by ${drop.creatorUsername}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (locked && drop.isWithinUnlockRange)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.near_me, color: Colors.amber, size: 18),
                ),
              if (drop.isPrivate)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.lock, color: Colors.purple, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
