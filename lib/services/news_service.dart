import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/news_article.dart';

class _NewsFeed {
  final String url;
  final String sourceName;
  final NewsTier tier;
  final String? category;
  const _NewsFeed(this.url, this.sourceName, this.tier, {this.category});
}

/// Pulls, parses, and merges Kenyan/African/global news RSS feeds for
/// the "Updates" section of the feed tab.
///
/// Kenyan outlets are fetched first and always sort ahead of Africa
/// and world stories (see [_tierRank] in [latest]) — that's the whole
/// point of the tab: what's happening at home, before what's
/// happening everywhere else. Every story links back to the original
/// publisher; nothing here is a copy of the article, just a headline,
/// a short summary, and a "View full story" link out.
class NewsService {
  NewsService._();
  static final NewsService instance = NewsService._();

  // Sports/Business/Technology feeds below follow the same URL pattern
  // The Standard already uses for headlines/entertainment, and BBC's
  // long-stable topic-feed convention. Like every feed here, a stale
  // or renamed URL just yields zero stories for that topic (see
  // _fetchFeed's catchError below) rather than breaking the tab —
  // worth spot-checking these specific ones after adding them, since
  // they haven't been hit from this codebase before.
  static final List<_NewsFeed> _feeds = [
    // Kenya — general news
    _NewsFeed('https://www.kenyans.co.ke/feeds/news', 'Kenyans.co.ke',
        NewsTier.kenya),
    _NewsFeed('https://www.standardmedia.co.ke/rss/headlines.php',
        'The Standard', NewsTier.kenya),
    _NewsFeed('https://nation.africa/kenya/rss.xml', 'Nation', NewsTier.kenya),
    // Kenya — entertainment
    _NewsFeed('https://www.standardmedia.co.ke/rss/entertainment.php',
        'The Standard', NewsTier.kenya,
        category: 'Entertainment'),
    // Kenya — sports
    _NewsFeed('https://www.standardmedia.co.ke/rss/sports.php',
        'The Standard', NewsTier.kenya,
        category: 'Sports'),
    // Kenya — business
    _NewsFeed('https://www.standardmedia.co.ke/rss/business.php',
        'The Standard', NewsTier.kenya,
        category: 'Business'),
    // Africa
    _NewsFeed('https://feeds.bbci.co.uk/news/world/africa/rss.xml',
        'BBC Africa', NewsTier.africa),
    // Africa — sports
    _NewsFeed('https://feeds.bbci.co.uk/sport/africa/rss.xml', 'BBC Sport',
        NewsTier.africa,
        category: 'Sports'),
    // World
    _NewsFeed(
        'https://feeds.bbci.co.uk/news/world/rss.xml', 'BBC News', NewsTier.world),
    // World — business
    _NewsFeed('https://feeds.bbci.co.uk/news/business/rss.xml', 'BBC News',
        NewsTier.world,
        category: 'Business'),
    // World — technology
    _NewsFeed('https://feeds.bbci.co.uk/news/technology/rss.xml', 'BBC News',
        NewsTier.world,
        category: 'Technology'),
  ];

  final _client = http.Client();

  /// Fetches every feed concurrently, parses whatever comes back
  /// (silently skipping any feed that fails or times out — one dead
  /// RSS endpoint shouldn't blank out the whole tab), de-duplicates by
  /// link, and returns everything sorted with Kenya first, then
  /// Africa, then world — newest within each tier.
  Future<List<NewsArticle>> latest() async {
    final results = await Future.wait(
      _feeds.map((f) => _fetchFeed(f).catchError((_) => <NewsArticle>[])),
    );

    final seen = <String>{};
    final merged = <NewsArticle>[];
    for (final list in results) {
      for (final article in list) {
        if (seen.add(article.id)) merged.add(article);
      }
    }

    merged.sort((a, b) {
      final tierCompare = _tierRank(a.tier).compareTo(_tierRank(b.tier));
      if (tierCompare != 0) return tierCompare;
      return b.publishedAt.compareTo(a.publishedAt);
    });

    return merged;
  }

  int _tierRank(NewsTier tier) {
    switch (tier) {
      case NewsTier.kenya:
        return 0;
      case NewsTier.africa:
        return 1;
      case NewsTier.world:
        return 2;
    }
  }

  Future<List<NewsArticle>> _fetchFeed(_NewsFeed feed) async {
    final response = await _client
        .get(Uri.parse(feed.url), headers: {
          // A handful of these feeds reject requests with no UA set.
          'User-Agent':
              'Mozilla/5.0 (Android; Mobile) RealmApp/1.0 (+news-reader)',
        })
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return [];

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final document = XmlDocument.parse(body);
    final items = document.findAllElements('item');

    return items
        .map((item) => _parseItem(item, feed))
        .whereType<NewsArticle>()
        .toList();
  }

  NewsArticle? _parseItem(XmlElement item, _NewsFeed feed) {
    final title = _text(item, 'title');
    final link = _text(item, 'link') ?? _guid(item);
    if (title == null || link == null) return null;

    final rawDescription = _text(item, 'description');
    final summary = _cleanSummary(rawDescription);
    final pubDateRaw = _text(item, 'pubDate') ?? _text(item, 'pubdate');
    final publishedAt = _parseDate(pubDateRaw);
    final imageUrl = _extractImage(item, rawDescription);

    return NewsArticle(
      id: link,
      title: _decodeEntities(title).trim(),
      summary: summary,
      link: link,
      imageUrl: imageUrl,
      sourceName: feed.sourceName,
      tier: feed.tier,
      category: feed.category,
      publishedAt: publishedAt,
    );
  }

  String? _text(XmlElement item, String tag) {
    final el = item.findElements(tag).firstOrNull;
    final value = el?.innerText.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _guid(XmlElement item) {
    final el = item.findElements('guid').firstOrNull;
    final value = el?.innerText.trim();
    if (value == null || value.isEmpty) return null;
    // Only usable as a link if it actually looks like a URL — some
    // feeds put a non-URL id in <guid>.
    return value.startsWith('http') ? value : null;
  }

  /// Looks for an image in the usual RSS/Media-RSS spots, in order of
  /// how reliable they tend to be: media:content, media:thumbnail,
  /// enclosure, then finally scraping the first <img> out of the raw
  /// HTML description as a last resort.
  String? _extractImage(XmlElement item, String? rawDescription) {
    for (final tag in ['media:content', 'media:thumbnail']) {
      final el = item.findElements(tag).firstOrNull;
      final url = el?.getAttribute('url');
      if (url != null && url.isNotEmpty) return url;
    }
    final enclosure = item.findElements('enclosure').firstOrNull;
    final enclosureType = enclosure?.getAttribute('type') ?? '';
    final enclosureUrl = enclosure?.getAttribute('url');
    if (enclosureUrl != null &&
        (enclosureType.startsWith('image') || enclosureType.isEmpty)) {
      return enclosureUrl;
    }
    if (rawDescription != null) {
      final match = RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(rawDescription);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Strips HTML tags/entities from an RSS <description> and trims it
  /// to a snippet-length summary — feeds routinely embed a full HTML
  /// blob (links, spans, sometimes an <img>) in there.
  String? _cleanSummary(String? raw) {
    if (raw == null) return null;
    final withoutTags = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final decoded = _decodeEntities(withoutTags);
    final collapsed = decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return null;
    return collapsed.length > 220
        ? '${collapsed.substring(0, 220).trim()}…'
        : collapsed;
  }

  String _decodeEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  DateTime _parseDate(String? raw) {
    if (raw == null) return DateTime.now();
    try {
      // RFC-822 style, e.g. "Fri, 24 Jul 2026 01:53:36 +0300" — the
      // format basically every RSS <pubDate> uses.
      return _RssDate.parse(raw);
    } catch (_) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Minimal RFC-822/HTTP-date parser — avoids pulling in `dart:io`
/// (unavailable cleanly alongside some of this app's web-adjacent
/// tooling) just for `_RssDate.parse`.
class _RssDate {
  static final _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  static DateTime parse(String input) {
    // e.g. "Fri, 24 Jul 2026 01:53:36 +0300" or "...GMT"
    final cleaned = input.trim();
    final match = RegExp(
            r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s*([+-]\d{4}|GMT|UTC)?')
        .firstMatch(cleaned);
    if (match == null) throw FormatException('Not an RFC-822 date: $input');
    final day = int.parse(match.group(1)!);
    final month = _months[match.group(2)!] ?? 1;
    final year = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final tz = match.group(7);

    var dt = DateTime.utc(year, month, day, hour, minute, second);
    if (tz != null && tz != 'GMT' && tz != 'UTC') {
      final sign = tz.startsWith('-') ? -1 : 1;
      final offsetHours = int.parse(tz.substring(1, 3));
      final offsetMinutes = int.parse(tz.substring(3, 5));
      dt = dt.subtract(
          Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes));
    }
    return dt.toLocal();
  }
}
