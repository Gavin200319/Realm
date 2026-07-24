import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_article.dart';
import '../services/news_service.dart';
import '../services/supabase_service.dart';
import '../services/local_cache_service.dart';
import '../services/article_image_service.dart';
import '../services/generated_image_service.dart';
import '../theme/rm_theme.dart';
import '../widgets/news_card.dart';
import 'news_comments_sheet.dart';
import 'news_detail_screen.dart';
import 'news_redrop_sheet.dart';

/// The "Updates" side of the Realm tab's Drops/Updates toggle — real
/// news, syndicated from Kenyan outlets first (general + entertainment),
/// then Africa, then the rest of the world. Every card links back to
/// the original publisher; nothing here is stored or reproduced beyond
/// a headline and a short summary.
class UpdatesView extends StatefulWidget {
  const UpdatesView({super.key});

  @override
  State<UpdatesView> createState() => UpdatesViewState();
}

class UpdatesViewState extends State<UpdatesView> {
  static const _cacheKey = 'news_updates';

  // Topic filter for the FAB below — matched against NewsArticle.category
  // (see news_service.dart's feed list for which categories actually
  // have real feeds behind them). "News" is its own entry rather than
  // folded into "All" because most stories have category == null, so
  // it needs an explicit bucket to be selectable on its own.
  static final List<_NewsFilterOption> _filterOptions = [
    _NewsFilterOption('All updates', Icons.dynamic_feed_rounded, null),
    _NewsFilterOption('News', Icons.newspaper_rounded, ''),
    _NewsFilterOption('Entertainment', Icons.theater_comedy_rounded, 'Entertainment'),
    _NewsFilterOption('Sports', Icons.sports_soccer_rounded, 'Sports'),
    _NewsFilterOption('Business', Icons.trending_up_rounded, 'Business'),
    _NewsFilterOption('Technology', Icons.memory_rounded, 'Technology'),
  ];

  List<NewsArticle> _articles = [];
  bool _loading = true;
  bool _offline = false;
  String? _error;
  int _filterIndex = 0; // index into _filterOptions; 0 = All updates
  bool _hideBreaking = false;

  List<NewsArticle> get _filteredArticles {
    final option = _filterOptions[_filterIndex];
    Iterable<NewsArticle> result = _articles;
    if (option.category == '') {
      result = result.where((a) => a.category == null); // "News"
    } else if (option.category != null) {
      result = result.where((a) => a.category == option.category);
    } // else "All updates" — no category filtering
    if (_hideBreaking) {
      result = result.where((a) => !a.isBreaking);
    }
    return result.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCached();
    refresh();
  }

  Future<void> _loadCached() async {
    final cached = await LocalCacheService.instance.loadList(_cacheKey);
    if (cached != null && cached.isNotEmpty && mounted && _articles.isEmpty) {
      setState(() {
        _articles = cached.map(NewsArticle.fromMap).toList();
        _loading = false;
      });
    }
  }

  /// Called on pull-to-refresh, and whenever the Updates segment is
  /// (re)selected from [FeedScreen] — same "never sit on stale data"
  /// contract as the Drops feed.
  Future<void> refresh() async {
    if (_articles.isEmpty) setState(() { _loading = true; _error = null; });
    try {
      final articles = await NewsService.instance.latest();
      if (mounted) {
        setState(() {
          _articles = articles;
          _offline = false;
          _error = null;
        });
      }
      await LocalCacheService.instance
          .saveList(_cacheKey, articles.map((a) => a.toMap()).toList());
    } catch (e) {
      if (mounted) {
        if (_articles.isNotEmpty) {
          setState(() => _offline = true);
        } else {
          setState(() => _error = 'Could not load news right now.');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternal(NewsArticle article) async {
    final uri = Uri.tryParse(article.link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openDetail(NewsArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
    );
  }

  Future<void> _openComments(NewsArticle article) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsCommentsSheet(article: article),
    );
  }

  Future<RedropOutcome?> _openRedropSheet(NewsArticle article) {
    return showModalBottomSheet<RedropOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsRedropSheet(article: article),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: RMColors.primary),
            SizedBox(height: 16),
            Text('Fetching the latest…',
                style: TextStyle(color: RMColors.textSecondary)),
          ],
        ),
      );
    }
    if (_error != null && _articles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: RMColors.textHint, size: 48),
              SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RMColors.textSecondary)),
              SizedBox(height: 20),
              OutlinedButton(onPressed: refresh, child: Text('Try again')),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredArticles;

    return Stack(
      children: [
        RefreshIndicator(
          color: RMColors.primary,
          backgroundColor: RMColors.surface,
          onRefresh: refresh,
          child: filtered.isEmpty
              ? _buildEmptyFilterState()
              : ListView.separated(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length + (_offline ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (_offline && index == 0) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: RMColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 16, color: RMColors.textHint),
                            SizedBox(width: 8),
                            Text('Offline — showing saved stories',
                                style: TextStyle(
                                    color: RMColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      );
                    }
                    final article = filtered[index - (_offline ? 1 : 0)];
                    return _NewsCardWithCount(
                      key: ValueKey(article.id),
                      article: article,
                      onOpenDetail: _openDetail,
                      onOpenExternal: _openExternal,
                      onOpenComments: _openComments,
                      onOpenRedropSheet: _openRedropSheet,
                    );
                  },
                ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _NewsFilterFab(
            options: _filterOptions,
            selectedIndex: _filterIndex,
            onSelect: (index) => setState(() => _filterIndex = index),
            hideBreaking: _hideBreaking,
            onHideBreakingChanged: (value) =>
                setState(() => _hideBreaking = value),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilterState() {
    final option = _filterOptions[_filterIndex];
    final topicLabel = option.category == null ? null : option.label;
    final label = [topicLabel, _hideBreaking ? 'non-breaking' : null]
        .whereType<String>()
        .join(', ');
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 80),
      children: [
        Column(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: RMColors.textHint, size: 40),
            SizedBox(height: 14),
            Text(
              label.isEmpty ? 'No stories right now' : 'No $label stories right now',
              style: TextStyle(color: RMColors.textSecondary),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _filterIndex = 0;
                _hideBreaking = false;
              }),
              child: Text('Show all updates'),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewsFilterOption {
  final String label;
  final IconData icon;
  // null = "All updates" (no filtering). '' = the "News" bucket, i.e.
  // articles with no category at all. Anything else matches
  // NewsArticle.category exactly.
  final String? category;
  const _NewsFilterOption(this.label, this.icon, this.category);
}

/// The FAB "down the Updates tab" that lets someone jump straight to
/// a topic — tapping it opens a short list of options upward (News,
/// Entertainment, Sports, Business, Technology, or everything) rather
/// than navigating to a separate filter screen, since there are only
/// a handful of topics and the whole point is a quick one-tap switch
/// without losing your place in the feed.
class _NewsFilterFab extends StatefulWidget {
  final List<_NewsFilterOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool hideBreaking;
  final ValueChanged<bool> onHideBreakingChanged;

  const _NewsFilterFab({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
    required this.hideBreaking,
    required this.onHideBreakingChanged,
  });

  @override
  State<_NewsFilterFab> createState() => _NewsFilterFabState();
}

class _NewsFilterFabState extends State<_NewsFilterFab> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _select(int index) {
    widget.onSelect(index);
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options[widget.selectedIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Options list, opening upward above the FAB ─────────────
        AnimatedSwitcher(
          duration: Duration(milliseconds: 160),
          child: _open
              ? Container(
                  key: ValueKey('open'),
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: RMColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RMColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.options.length; i++)
                        _FilterOptionTile(
                          option: widget.options[i],
                          selected: i == widget.selectedIndex,
                          onTap: () => _select(i),
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(height: 1, color: RMColors.border),
                      ),
                      _BreakingToggleTile(
                        value: widget.hideBreaking,
                        onChanged: widget.onHideBreakingChanged,
                      ),
                    ],
                  ),
                )
              : SizedBox.shrink(key: ValueKey('closed')),
        ),
        // ── The FAB itself — icon reflects the active filter, and a
        // small dot marks that a filter (other than "All") or the
        // breaking-news toggle is on, so it's obvious at a glance
        // even when the menu is closed.
        Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton(
              heroTag: 'updates_filter_fab',
              backgroundColor: RMColors.primary,
              foregroundColor: Colors.white,
              onPressed: _toggle,
              tooltip: 'Filter updates',
              child: Icon(_open ? Icons.close_rounded : selected.icon),
            ),
            if (!_open && (widget.selectedIndex != 0 || widget.hideBreaking))
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: RMColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: RMColors.background, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  final _NewsFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(option.icon,
                size: 18,
                color: selected ? RMColors.primary : RMColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  color: selected ? RMColors.primary : RMColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: RMColors.primary),
          ],
        ),
      ),
    );
  }
}

class _BreakingToggleTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BreakingToggleTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        width: 200,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 18,
                color: value ? RMColors.primary : RMColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hide breaking news',
                style: TextStyle(
                  color: value ? RMColors.primary : RMColors.textPrimary,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: RMColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [NewsCard] with a lazily-fetched comment count, resolved
/// once per card the same way [DropCard] lazily resolves its place
/// name — cheap, best-effort, and never blocks the card from showing.
class _NewsCardWithCount extends StatefulWidget {
  final NewsArticle article;
  final void Function(NewsArticle) onOpenDetail;
  final void Function(NewsArticle) onOpenExternal;
  final Future<void> Function(NewsArticle) onOpenComments;
  final Future<RedropOutcome?> Function(NewsArticle) onOpenRedropSheet;

  const _NewsCardWithCount({
    super.key,
    required this.article,
    required this.onOpenDetail,
    required this.onOpenExternal,
    required this.onOpenComments,
    required this.onOpenRedropSheet,
  });

  @override
  State<_NewsCardWithCount> createState() => _NewsCardWithCountState();
}

class _NewsCardWithCountState extends State<_NewsCardWithCount> {
  int? _count;
  int? _redropCount;
  bool _iRedropped = false;
  NewsArticle? _resolvedArticle;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _loadRedropState();
    _resolveImageIfMissing();
  }

  @override
  void didUpdateWidget(_NewsCardWithCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _resolvedArticle = null;
      _resolveImageIfMissing();
    }
  }

  Future<void> _loadCount() async {
    try {
      final count =
          await SupabaseService.instance.fetchNewsCommentCount(widget.article.link);
      if (mounted) setState(() => _count = count);
    } catch (_) {
      // Best-effort — the count pill just stays generic without it.
    }
  }

  Future<void> _loadRedropState() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchNewsRedropCount(widget.article.link),
        SupabaseService.instance.fetchMyNewsRedrop(widget.article.link),
      ]);
      if (!mounted) return;
      setState(() {
        _redropCount = results[0] as int;
        _iRedropped = (results[1] as Map<String, dynamic>?) != null;
      });
    } catch (_) {
      // Best-effort, same contract as _loadCount above.
    }
  }

  /// If the feed didn't give us an image, first look one up from the
  /// story's own page (see [ArticleImageService]); if that also comes
  /// up empty, fall back to a generated illustration (see
  /// [GeneratedImageService], which is itself a no-op unless the
  /// person running this app has opted in with an API key). Same
  /// "cheap, best-effort, never blocks the card" contract throughout.
  Future<void> _resolveImageIfMissing() async {
    if (widget.article.imageUrl != null) return;
    try {
      final result =
          await ArticleImageService.instance.resolve(widget.article.link);
      if (result != null) {
        if (!mounted) return;
        setState(() {
          _resolvedArticle = widget.article.withResolvedImage(
            imageUrl: result.imageUrl,
            imageCredit: result.credit,
          );
        });
        return;
      }
    } catch (_) {
      // Fall through to the generated-illustration attempt below.
    }

    if (!GeneratedImageService.instance.shouldGenerate(widget.article)) {
      return;
    }
    try {
      final bytes =
          await GeneratedImageService.instance.generate(widget.article);
      if (bytes == null || !mounted) return;
      setState(() {
        _resolvedArticle = widget.article.withGeneratedImage(bytes);
      });
    } catch (_) {
      // No image, generated or otherwise — the card still works fine.
    }
  }

  Future<void> _handleRedrop() async {
    final outcome = await widget.onOpenRedropSheet(_resolvedArticle ?? widget.article);
    if (outcome == null || !mounted) return;
    if (outcome == RedropOutcome.sharedToStatus) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Shared to your status')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Redropped')));
    }
    _loadRedropState();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedArticle ?? widget.article;
    return NewsCard(
      article: resolved,
      commentCount: _count,
      redropCount: _redropCount,
      iRedropped: _iRedropped,
      onOpenDetail: () => widget.onOpenDetail(resolved),
      onOpenExternal: () => widget.onOpenExternal(resolved),
      onOpenComments: () async {
        // Refresh the count once the sheet actually closes, in case
        // the person just added a comment. Passing the resolved
        // article through means the comments sheet's header (if it
        // shows one) also gets the story's image, same as the detail
        // screen and redrop sheet.
        await widget.onOpenComments(resolved);
        _loadCount();
      },
      onRedrop: _handleRedrop,
    );
  }
}
