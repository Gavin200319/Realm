import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';

class CreateDropScreen extends StatefulWidget {
  final double lat;
  final double lng;

  const CreateDropScreen({super.key, required this.lat, required this.lng});

  @override
  State<CreateDropScreen> createState() => _CreateDropScreenState();
}

class _CreateDropScreenState extends State<CreateDropScreen> {
  final _captionCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  int _radius = 50;
  File? _mediaFile;
  String _mediaType = 'photo';
  String _visibility = 'public';
  List<String> _allowedUsers = []; // usernames on the allowlist
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _saving = false;
  bool _searchingUsers = false;
  String? _error;

  @override
  void dispose() {
    _captionCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(String type) async {
    setState(() => _mediaType = type);
    if (type == 'document') {
      // Document picking needs file_picker package — for v2 show a note
      setState(() => _error = 'Document upload coming soon — use photo or video for now.');
      return;
    }
    final picked = await ImagePicker().pickMedia(maxWidth: 1600, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _mediaFile = File(picked.path);
        _mediaType = picked.path.endsWith('.mp4') || picked.path.endsWith('.mov')
            ? 'video'
            : 'photo';
        _error = null;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _userSuggestions = []);
      return;
    }
    setState(() => _searchingUsers = true);
    try {
      final results = await SupabaseService.instance.searchUsers(query);
      // Filter out already-added users and current user
      final currentUsername = SupabaseService.instance.currentUser?.id;
      setState(() {
        _userSuggestions = results
            .where((u) =>
                !_allowedUsers.contains(u['username']) &&
                u['id'] != currentUsername)
            .toList();
      });
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  void _addUser(String username) {
    setState(() {
      if (!_allowedUsers.contains(username)) {
        _allowedUsers.add(username);
      }
      _userSearchCtrl.clear();
      _userSuggestions = [];
    });
  }

  void _removeUser(String username) {
    setState(() => _allowedUsers.remove(username));
  }

  Future<void> _save() async {
    if (_captionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Add a caption before dropping.');
      return;
    }
    if (_visibility == 'private' && _allowedUsers.isEmpty) {
      setState(() => _error = 'Add at least one user to the allowlist, or set to public.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? mediaUrl;
      if (_mediaFile != null) {
        final bytes = await _mediaFile!.readAsBytes();
        final ext = _mediaType == 'video' ? 'mp4' : 'jpg';
        mediaUrl = await SupabaseService.instance.uploadDropMedia(
          bytes: bytes,
          mediaType: _mediaType,
          extension: ext,
        );
      }

      await SupabaseService.instance.createDrop(
        lat: widget.lat,
        lng: widget.lng,
        caption: _captionCtrl.text.trim(),
        mediaUrl: mediaUrl,
        mediaType: _mediaFile != null ? _mediaType : null,
        unlockRadiusM: _radius,
        visibility: _visibility,
      );

      // If private, grant access to each allowed user
      // We need the drop id — fetch the most recent drop by this user
      if (_visibility == 'private' && _allowedUsers.isNotEmpty) {
        final user = SupabaseService.instance.currentUser!;
        final rows = await SupabaseService.instance.fetchLatestDropId(user.id);
        if (rows != null) {
          for (final username in _allowedUsers) {
            await SupabaseService.instance.grantDropAccess(
              dropId: rows,
              username: username,
            );
          }
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Drop here')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media picker row
            Row(
              children: [
                _MediaTypeButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photo',
                  selected: _mediaType == 'photo',
                  onTap: () => _pickMedia('photo'),
                ),
                const SizedBox(width: 8),
                _MediaTypeButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  selected: _mediaType == 'video',
                  onTap: () => _pickMedia('video'),
                ),
                const SizedBox(width: 8),
                _MediaTypeButton(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Document',
                  selected: _mediaType == 'document',
                  onTap: () => _pickMedia('document'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Media preview
            if (_mediaFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _mediaType == 'video'
                    ? Container(
                        height: 120,
                        color: Colors.black45,
                        child: const Center(
                          child: Icon(Icons.videocam, size: 48),
                        ),
                      )
                    : Image.file(_mediaFile!, height: 180, fit: BoxFit.cover),
              ),
            if (_mediaFile == null)
              GestureDetector(
                onTap: () => _pickMedia('photo'),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_a_photo_outlined, size: 32),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Caption
            TextField(
              controller: _captionCtrl,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What do you want to leave here?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Unlock radius
            Text('Unlock radius: ${_radius}m'),
            Slider(
              value: _radius.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              label: '${_radius}m',
              onChanged: (v) => setState(() => _radius = v.round()),
            ),
            const SizedBox(height: 12),

            // Visibility toggle
            Row(
              children: [
                const Text('Visibility:'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('🌍  Public'),
                  selected: _visibility == 'public',
                  onSelected: (_) => setState(() => _visibility = 'public'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🔒  Private'),
                  selected: _visibility == 'private',
                  onSelected: (_) => setState(() => _visibility = 'private'),
                ),
              ],
            ),

            // Allowlist — only shown for private drops
            if (_visibility == 'private') ...[
              const SizedBox(height: 16),
              Text(
                'Who can unlock this?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              // Added users chips
              if (_allowedUsers.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _allowedUsers
                      .map((u) => Chip(
                            label: Text('@$u'),
                            onDeleted: () => _removeUser(u),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 8),

              // User search field
              TextField(
                controller: _userSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search by username',
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchingUsers
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _searchUsers,
              ),

              // Search results
              if (_userSuggestions.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = _userSuggestions[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text('@${u['username']}'),
                        subtitle: Text(u['display_name'] ?? ''),
                        onTap: () => _addUser(u['username'] as String),
                      );
                    },
                  ),
                ),
            ],

            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Drop it here'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MediaTypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
