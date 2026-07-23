/// Which tier a source belongs to — drives both sort order and the
/// little badge on each card. Kenya stories always sort ahead of
/// Africa/world ones (see [NewsService]), which is the actual point
/// of this whole tab: local news is the priority, not an afterthought
/// buried under global headlines.
enum NewsTier { kenya, africa, world }

NewsTier _tierFromName(String raw) {
  switch (raw) {
    case 'africa':
      return NewsTier.africa;
    case 'world':
      return NewsTier.world;
    default:
      return NewsTier.kenya;
  }
}

/// One story pulled from an RSS feed. Deliberately thin — this is a
/// syndicated headline + short summary + link back to the publisher,
/// not a copy of the article itself.
class NewsArticle {
  /// Stable id derived from the article link — used as the primary
  /// key for comments and for de-duplicating the same story if it
  /// happens to show up in more than one feed.
  final String id;
  final String title;
  final String? summary;
  final String link;
  final String? imageUrl;
  final String sourceName;
  final NewsTier tier;
  final String? category; // e.g. "Entertainment", "Politics" — optional
  final DateTime publishedAt;

  NewsArticle({
    required this.id,
    required this.title,
    this.summary,
    required this.link,
    this.imageUrl,
    required this.sourceName,
    required this.tier,
    this.category,
    required this.publishedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'summary': summary,
        'link': link,
        'image_url': imageUrl,
        'source_name': sourceName,
        'tier': tier.name,
        'category': category,
        'published_at': publishedAt.toIso8601String(),
      };

  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    return NewsArticle(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String?,
      link: map['link'] as String,
      imageUrl: map['image_url'] as String?,
      sourceName: map['source_name'] as String? ?? '',
      tier: _tierFromName(map['tier'] as String? ?? 'kenya'),
      category: map['category'] as String?,
      publishedAt:
          DateTime.tryParse(map['published_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  /// Short "3h ago" / "2d ago" style label, matching the tone of
  /// [Drop.distanceLabel] elsewhere in the app.
  String get timeAgoLabel {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
