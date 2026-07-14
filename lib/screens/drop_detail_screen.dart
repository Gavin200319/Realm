import 'package:flutter/material.dart';
import '../models/drop.dart';
import '../services/supabase_service.dart';
import 'reactions_screen.dart';

class DropDetailScreen extends StatefulWidget {
  final Drop drop;
  final double currentLat;
  final double currentLng;

  const DropDetailScreen({
    super.key,
    required this.drop,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<DropDetailScreen> createState() => _DropDetailScreenState();
}

class _DropDetailScreenState extends State<DropDetailScreen> {
  bool _unlocking = false;
  String? _error;
  late bool _unlocked;

  @override
  void initState() {
    super.initState();
    _unlocked = widget.drop.isUnlocked;
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final success = await SupabaseService.instance.attemptUnlock(
        dropId: widget.drop.id,
        lat: widget.currentLat,
        lng: widget.currentLng,
      );
      if (success) {
        setState(() => _unlocked = true);
      } else {
        setState(() => _error =
            'Still too far away — get within ${widget.drop.unlockRadiusM}m.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drop = widget.drop;
    return Scaffold(
      appBar: AppBar(title: const Text('Drop')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_unlocked) ...[
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'This Drop is locked.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(drop.distanceLabel),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _unlocking ? null : _unlock,
                child: _unlocking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Try to unlock'),
              ),
            ] else ...[
              if (drop.mediaUrl != null) ...[
                if (drop.mediaType == DropMediaType.photo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(drop.mediaUrl!),
                  )
                else if (drop.mediaType == DropMediaType.video)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 56),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              // TODO: open video player in v3
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Video player coming in v3')),
                              );
                            },
                            child: const Text('Tap to play video'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (drop.mediaType == DropMediaType.document)
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file, size: 40),
                    title: const Text('Attached document'),
                    subtitle: const Text('Tap to open'),
                    onTap: () {
                      // TODO: open document viewer in v3
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Document viewer coming in v3')),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
              if (drop.isPrivate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 14, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text('Private drop',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.purple)),
                    ],
                  ),
                ),
              Text(drop.caption ?? '', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text('by ${drop.creatorUsername}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReactionsScreen(dropId: drop.id),
                  ),
                ),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Reactions & Comments'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
