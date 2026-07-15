import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/onboarding_service.dart';
import '../theme/rm_theme.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/location_autocomplete_field.dart';

class CreateDropScreen extends StatefulWidget {
  final double lat;
  final double lng;

  const CreateDropScreen({super.key, required this.lat, required this.lng});

  @override
  State<CreateDropScreen> createState() => _CreateDropScreenState();
}

class _CreateDropScreenState extends State<CreateDropScreen>
    with SingleTickerProviderStateMixin {
  final _captionCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  int _radius = 50;
  File? _mediaFile;
  String _mediaType = 'photo';
  String _fileName = '';
  String _visibility = 'public';
  List<String> _allowedUsers = [];
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _saving = false;
  bool _searchingUsers = false;
  bool _showTutorial = false;
  String? _error;

  late AnimationController _enterCtrl;
  late Animation<double> _enterFade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _checkTutorial();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _userSearchCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkTutorial() async {
    final show = await OnboardingService.instance.shouldShowDropTutorial();
    if (mounted) setState(() => _showTutorial = show);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _mediaFile = File(picked.path);
        _mediaType = 'photo';
        _fileName = picked.name;
        _error = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked != null) {
      setState(() {
        _mediaFile = File(picked.path);
        _mediaType = 'video';
        _fileName = picked.name;
        _error = null;
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaFile = File(result.files.single.path!);
        _mediaType = 'document';
        _fileName = result.files.single.name;
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
      setState(() {
        _userSuggestions = results
            .where((u) => !_allowedUsers.contains(u['username']))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  void _addUser(String username) {
    setState(() {
      if (!_allowedUsers.contains(username)) _allowedUsers.add(username);
      _userSearchCtrl.clear();
      _userSuggestions = [];
    });
  }

  String get _fileExt {
    if (_mediaFile == null) return 'jpg';
    final path = _mediaFile!.path;
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  }

  Future<void> _save() async {
    if (_captionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Add a caption before dropping.');
      return;
    }
    if (_visibility == 'private' && _allowedUsers.isEmpty) {
      setState(() => _error =
          'Add at least one person to the allowlist, or set visibility to public.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      String? mediaUrl;
      if (_mediaFile != null) {
        final bytes = await _mediaFile!.readAsBytes();
        mediaUrl = await SupabaseService.instance.uploadDropMedia(
          bytes: bytes,
          mediaType: _mediaType,
          extension: _fileExt,
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

      // Grant access to allowlist users
      if (_visibility == 'private' && _allowedUsers.isNotEmpty) {
        final dropId = await SupabaseService.instance
            .fetchLatestDropId(SupabaseService.instance.currentUser!.id);
        if (dropId != null) {
          for (final username in _allowedUsers) {
            await SupabaseService.instance.grantDropAccess(
              dropId: dropId,
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: RMColors.background,
          appBar: AppBar(
            title: const Text('Leave a Drop'),
            backgroundColor: RMColors.background,
          ),
          body: FadeTransition(
            opacity: _enterFade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Media picker row
                  Row(
                    children: [
                      _MediaPicker(
                        icon: Icons.photo_camera_rounded,
                        label: 'Photo',
                        selected: _mediaType == 'photo' && _mediaFile != null,
                        onTap: _pickPhoto,
                      ),
                      const SizedBox(width: 10),
                      _MediaPicker(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        selected: _mediaType == 'video' && _mediaFile != null,
                        onTap: _pickVideo,
                      ),
                      const SizedBox(width: 10),
                      _MediaPicker(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Document',
                        selected: _mediaType == 'document' && _mediaFile != null,
                        onTap: _pickDocument,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Media preview
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _mediaFile == null
                        ? const SizedBox.shrink()
                        : _buildMediaPreview(),
                  ),
                  if (_mediaFile != null) const SizedBox(height: 14),

                  // Caption
                  TextField(
                    controller: _captionCtrl,
                    maxLength: 500,
                    maxLines: 4,
                    style: const TextStyle(color: RMColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'What do you want to leave here?',
                      counterStyle: TextStyle(color: RMColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Unlock radius
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Unlock radius',
                          style: TextStyle(
                              color: RMColors.textSecondary, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: RMColors.primaryDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_radius}m',
                          style: const TextStyle(
                              color: RMColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: RMColors.primary,
                      inactiveTrackColor: RMColors.border,
                      thumbColor: RMColors.primary,
                      overlayColor: RMColors.primary.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: _radius.toDouble(),
                      min: 10,
                      max: 200,
                      divisions: 19,
                      onChanged: (v) => setState(() => _radius = v.round()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visibility
                  const Text('Who can see this?',
                      style: TextStyle(
                          color: RMColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _VisibilityChip(
                        label: 'Public',
                        icon: Icons.public_rounded,
                        selected: _visibility == 'public',
                        onTap: () =>
                            setState(() => _visibility = 'public'),
                      ),
                      const SizedBox(width: 10),
                      _VisibilityChip(
                        label: 'Private',
                        icon: Icons.lock_rounded,
                        selected: _visibility == 'private',
                        onTap: () =>
                            setState(() => _visibility = 'private'),
                      ),
                    ],
                  ),

                  // Allowlist
                  if (_visibility == 'private') ...[
                    const SizedBox(height: 20),
                    const Text('Who can unlock this?',
                        style: TextStyle(
                            color: RMColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    if (_allowedUsers.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allowedUsers
                            .map((u) => Chip(
                                  label: Text('@$u'),
                                  onDeleted: () => setState(
                                      () => _allowedUsers.remove(u)),
                                  deleteIconColor: RMColors.textSecondary,
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _userSearchCtrl,
                      style: const TextStyle(color: RMColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Search by username',
                        suffixIcon: _searchingUsers
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: RMColors.primary),
                                ),
                              )
                            : null,
                      ),
                      onChanged: _searchUsers,
                    ),
                    if (_userSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: RMColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: RMColors.border),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _userSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: RMColors.border),
                          itemBuilder: (context, i) {
                            final u = _userSuggestions[i];
                            return ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 16,
                                backgroundColor: RMColors.primaryDim,
                                child: Icon(Icons.person_rounded,
                                    size: 16, color: RMColors.primary),
                              ),
                              title: Text('@${u['username']}',
                                  style: const TextStyle(
                                      color: RMColors.textPrimary,
                                      fontSize: 14)),
                              subtitle: Text(u['display_name'] ?? '',
                                  style: const TextStyle(
                                      color: RMColors.textSecondary,
                                      fontSize: 12)),
                              onTap: () =>
                                  _addUser(u['username'] as String),
                            );
                          },
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: RMColors.danger, fontSize: 13)),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Drop it here'),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_showTutorial)
          TutorialOverlay(
            steps: const [
              TutorialStep(
                icon: Icons.add_location_alt_rounded,
                title: 'Create a Drop',
                body: 'You\'re pinning content to your exact GPS location. Anyone who walks here can discover it.',
              ),
              TutorialStep(
                icon: Icons.perm_media_rounded,
                title: 'Add any media',
                body: 'Attach a photo, video, or document. The content stays hidden until someone physically unlocks it.',
              ),
              TutorialStep(
                icon: Icons.lock_rounded,
                title: 'Set visibility',
                body: 'Public drops are discoverable by everyone. Private drops are only visible to people you add by username.',
              ),
            ],
            onDone: () async {
              await OnboardingService.instance.markDropTutorialSeen();
              if (mounted) setState(() => _showTutorial = false);
            },
          ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    if (_mediaType == 'photo') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(_mediaFile!, height: 180, fit: BoxFit.cover,
            key: const ValueKey('photo')),
      );
    }
    return Container(
      key: ValueKey(_mediaType),
      height: 80,
      decoration: BoxDecoration(
        color: RMColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RMColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            _mediaType == 'video'
                ? Icons.videocam_rounded
                : Icons.insert_drive_file_rounded,
            color: RMColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _fileName,
              style: const TextStyle(
                  color: RMColors.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: RMColors.textSecondary, size: 18),
            onPressed: () =>
                setState(() { _mediaFile = null; _fileName = ''; }),
          ),
        ],
      ),
    );
  }
}

class _MediaPicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MediaPicker({
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? RMColors.primaryDim : RMColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? RMColors.primary : RMColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? RMColors.primary : RMColors.textHint,
                  size: 22),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? RMColors.primary
                          : RMColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? RMColors.primaryDim : RMColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? RMColors.primary : RMColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    selected ? RMColors.primary : RMColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? RMColors.primary
                        : RMColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
