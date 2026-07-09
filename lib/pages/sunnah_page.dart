import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../services/storage_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';
import '../static/mysnakbar.dart';
import '../static/mydialog.dart';

class SunnahPage extends StatefulWidget {
  const SunnahPage({super.key});

  @override
  State<SunnahPage> createState() => _SunnahPageState();
}

class _SunnahPageState extends State<SunnahPage> {
  static const String _downloadKeyPrefix = 'sunnah_book_json_';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final StorageService _storage;
  String _query = '';
  String? _expandedHadithKey;
  bool get _hasDownloadedEditions =>
      _books.any((book) => _storage.contains(_downloadKey(book.editionId)));
  final Set<String> _downloadingEditions = <String>{};
  final Map<String, List<_HadithEntry>> _hadithCache = {};

  // Lazy-loading for global search results
  List<_GlobalHadithResult> _cachedHadithResults = [];
  int _visibleHadithCount = 30;

  static final List<_SunnahBook> _books = [
    _SunnahBook(
      titleKey: 'book_bukhari_title',
      authorKey: 'book_bukhari_author',
      categoryKey: 'category_sahihayn',
      descriptionKey: 'book_bukhari_desc',
      bookKey: 'bukhari',
      topicsKeys: [
        'topic_faith',
        'topic_wudu',
        'topic_prayer',
        'topic_zakat',
        'topic_fasting',
        'topic_hajj',
        'topic_sales',
        'topic_marriage',
        'topic_jihad',
        'topic_manners',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_muslim_title',
      authorKey: 'book_muslim_author',
      categoryKey: 'category_sahihayn',
      descriptionKey: 'book_muslim_desc',
      bookKey: 'muslim',
      topicsKeys: [
        'topic_faith',
        'topic_purification',
        'topic_prayer',
        'topic_funerals',
        'topic_zakat',
        'topic_fasting',
        'topic_hajj',
        'topic_decree',
        'topic_righteousness',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_abudawud_title',
      authorKey: 'book_abudawud_author',
      categoryKey: 'category_sunan',
      descriptionKey: 'book_abudawud_desc',
      bookKey: 'abudawud',
      topicsKeys: [
        'topic_purification',
        'topic_prayer',
        'topic_zakat',
        'topic_fasting',
        'topic_rituals',
        'topic_marriage',
        'topic_divorce',
        'topic_sales',
        'topic_judgments',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_tirmidhi_title',
      authorKey: 'book_tirmidhi_author',
      categoryKey: 'category_sunan',
      descriptionKey: 'book_tirmidhi_desc',
      bookKey: 'tirmidhi',
      topicsKeys: [
        'topic_purification',
        'topic_prayer',
        'topic_witr',
        'topic_breastfeeding',
        'topic_sales',
        'topic_rulings',
        'topic_virtues',
        'topic_supplications',
        'topic_manners',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_nasai_title',
      authorKey: 'book_nasai_author',
      categoryKey: 'category_sunan',
      descriptionKey: 'book_nasai_desc',
      bookKey: 'nasai',
      topicsKeys: [
        'topic_purification',
        'topic_prayer_times',
        'topic_prayer',
        'topic_funerals',
        'topic_fasting',
        'topic_hajj',
        'topic_marriage',
        'topic_adornment',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_ibnmajah_title',
      authorKey: 'book_ibnmajah_author',
      categoryKey: 'category_sunan',
      descriptionKey: 'book_ibnmajah_desc',
      bookKey: 'ibnmajah',
      topicsKeys: [
        'topic_introduction',
        'topic_purification',
        'topic_prayer',
        'topic_zakat',
        'topic_fasting',
        'topic_trades',
        'topic_foods',
        'topic_medicine',
        'topic_asceticism',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_malik_title',
      authorKey: 'book_malik_author',
      categoryKey: 'category_muwattaat',
      descriptionKey: 'book_malik_desc',
      bookKey: 'malik',
      topicsKeys: [
        'topic_purification',
        'topic_prayer',
        'topic_quran',
        'topic_zakat',
        'topic_fasting',
        'topic_hajj',
        'topic_vows',
        'topic_judgments',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_qudsi_title',
      authorKey: 'book_qudsi_author',
      categoryKey: 'category_short_texts',
      descriptionKey: 'book_qudsi_desc',
      bookKey: 'qudsi',
      topicsKeys: [
        'topic_faith',
        'topic_sincerity',
        'topic_repentance',
        'topic_mercy',
        'topic_supplication',
        'topic_remembrance',
        'topic_piety',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_nawawi_title',
      authorKey: 'book_nawawi_author',
      categoryKey: 'category_short_texts',
      descriptionKey: 'book_nawawi_desc',
      bookKey: 'nawawi',
      topicsKeys: [
        'topic_intention',
        'topic_islam',
        'topic_faith',
        'topic_ihsan',
        'topic_halal',
        'topic_haram',
        'topic_advice',
        'topic_morals',
      ],
    ),
    _SunnahBook(
      titleKey: 'book_dehlawi_title',
      authorKey: 'book_dehlawi_author',
      categoryKey: 'category_short_texts',
      descriptionKey: 'book_dehlawi_desc',
      bookKey: 'dehlawi',
      topicsKeys: [
        'topic_faith',
        'topic_knowledge',
        'topic_morals',
        'topic_worship',
        'topic_soul_purification',
        'topic_behavior',
        'topic_etiquette',
      ],
    ),
  ];

  static final Map<String, List<String>> _relatedTerms = {
    'صلاة': ['الصلاة', 'الوتر', 'المواقيت', 'قيام', 'مسجد'],
    'صلاه': ['الصلاة', 'الوتر', 'المواقيت', 'قيام', 'مسجد'],
    'وضوء': ['الوضوء', 'الطهارة', 'الغسل', 'التيمم'],
    'طهارة': ['الطهارة', 'الوضوء', 'الغسل', 'التيمم'],
    'صيام': ['الصيام', 'الصوم', 'رمضان'],
    'صوم': ['الصيام', 'الصوم', 'رمضان'],
    'زكاة': ['الزكاة', 'صدقة'],
    'زكاه': ['الزكاة', 'صدقة'],
    'حج': ['الحج', 'المناسك', 'العمرة'],
    'بيع': ['البيوع', 'التجارات', 'المعاملات'],
    'تجارة': ['البيوع', 'التجارات', 'المعاملات'],
    'زواج': ['النكاح', 'الطلاق', 'الرضاع'],
    'نية': ['النية', 'الإخلاص'],
    'اخلاق': ['الأخلاق', 'الأدب', 'البر', 'الصبر', 'الصدق'],
    'دعاء': ['الدعاء', 'الدعوات', 'الأذكار'],
  };

  @override
  void initState() {
    super.initState();
    _storage = Get.find<StorageService>();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (_searchController.text.trim().isEmpty && _query.isNotEmpty) {
        _setQuery('');
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300.h) {
      if (_visibleHadithCount < _cachedHadithResults.length) {
        setState(() {
          _visibleHadithCount = (_visibleHadithCount + 30)
              .clamp(0, _cachedHadithResults.length);
        });
      }
    }
  }

  void _setQuery(String value) {
    final results = value.trim().isEmpty ? <_GlobalHadithResult>[] : _globalHadithResults(value);
    setState(() {
      _query = value;
      _expandedHadithKey = null;
      _cachedHadithResults = results;
      _visibleHadithCount = 30;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final results = _filteredBooks();
    final hasSearch = _query.trim().isNotEmpty;
    final visibleResults = _cachedHadithResults.take(_visibleHadithCount).toList();
    final hasMore = _visibleHadithCount < _cachedHadithResults.length;

    return PopScope(
      canPop: !hasSearch,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasSearch) {
          _searchController.clear();
          _setQuery('');
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ArabesqueBackground(
              child: SafeArea(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 104.h),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (hasSearch) ...[
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _setQuery('');
                            },
                            icon: const Icon(Icons.arrow_back),
                            color: goldColor,
                          ),
                          Expanded(
                            child: Text(
                              'sunnah_search_results_count'.trParams({'count': '${_cachedHadithResults.length}'}),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                    ] else ...[
                      _Header(goldColor: goldColor),
                    ],
                    SizedBox(height: 18.h),
                    _SearchBox(
                      controller: _searchController,
                      goldColor: goldColor,
                      onSubmitted: (value) {
                        _setQuery(value);
                      },
                      onClear: () {
                        _searchController.clear();
                        _setQuery('');
                      },
                    ),
                    SizedBox(height: 16.h),
                    if (hasSearch) ...[
                      if (!_hasDownloadedEditions)
                        _SearchHintCard(
                          goldColor: goldColor,
                          icon: Icons.download,
                          title: 'sunnah_download_first_title'.tr,
                          text: 'sunnah_download_first_desc'.tr,
                        )
                      else if (_cachedHadithResults.isEmpty)
                        _SearchHintCard(
                          goldColor: goldColor,
                          icon: Icons.manage_search,
                          title: 'sunnah_no_matching_hadiths_title'.tr,
                          text: 'sunnah_no_matching_hadiths_desc'.tr,
                        )
                      else ...[
                        ..._buildGroupedSearchResults(
                            visibleResults, goldColor, theme),
                        if (hasMore)
                          _LoadingMoreIndicator(goldColor: goldColor)
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Center(
                              child: Text(
                                'sunnah_end_of_results'.tr,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: goldColor, size: 18.r),
                          SizedBox(width: 8.w),
                          Text(
                            'sunnah_famous_books'.tr,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: goldColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'sunnah_books_count_label'.trParams({'count': '${results.length}'}),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      if (results.isEmpty)
                        _EmptySearch(goldColor: goldColor)
                      else
                        for (final book in results) ...[
                          _BookCard(
                            book: book,
                            goldColor: goldColor,
                            downloaded: _isDownloaded(book),
                            downloading: _isDownloading(book),
                            onDownload: () => _downloadBook(book),
                            onRead: () => _openBook(book),
                            onDelete: () => _deleteBook(book),
                          ),
                          SizedBox(height: 12.h),
                        ],
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: const AppBottomNav(currentIndex: 3),
          ),
        ),
      ),
    );
  }

  List<_SunnahBook> _filteredBooks() {
    final query = _normalize(_query);
    if (query.isEmpty) {
      return _books;
    }

    final terms = _expandedSearchTerms(query);
    final scored =
        _books
            .map((book) => MapEntry(book, _scoreBook(book, terms)))
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return scored.map((entry) => entry.key).toList();
  }

  List<_GlobalHadithResult> _globalHadithResults(String rawQuery) {
    final normalizedQuery = _normalize(rawQuery);
    if (normalizedQuery.isEmpty || !_hasDownloadedEditions) {
      return const <_GlobalHadithResult>[];
    }

    final terms = _expandedSearchTerms(normalizedQuery);
    // Collect top results PER BOOK so all downloaded books are represented
    const maxPerBook = 20;
    final allResults = <_GlobalHadithResult>[];

    for (final book in _books.where(_isDownloaded)) {
      final hadiths = _loadHadiths(book);
      final bookScored = <_ScoredGlobalHadithResult>[];

      for (final hadith in hadiths) {
        final score = _scoreHadith(hadith, terms);
        if (score > 0) {
          bookScored.add(
            _ScoredGlobalHadithResult(
              result: _GlobalHadithResult(book: book, hadith: hadith),
              score: score,
            ),
          );
        }
      }

      // Sort within this book and take top N
      bookScored.sort((a, b) => b.score.compareTo(a.score));
      allResults.addAll(
        bookScored.take(maxPerBook).map((s) => s.result),
      );
    }

    return allResults;
  }


  List<_HadithEntry> _loadHadiths(_SunnahBook book) {
    final cached = _hadithCache[book.editionId];
    if (cached != null) {
      return cached;
    }

    final rawBook = _storage.read<String>(_downloadKey(book.editionId), '');
    if (rawBook.isEmpty) {
      return const <_HadithEntry>[];
    }

    try {
      final hadiths = _parseHadiths(jsonDecode(rawBook));
      _hadithCache[book.editionId] = hadiths;
      return hadiths;
    } catch (_) {
      return const <_HadithEntry>[];
    }
  }

  int _scoreHadith(_HadithEntry hadith, Set<String> terms) {
    final text = _normalize(hadith.searchText);
    var score = 0;

    for (final term in terms) {
      if (term.isEmpty) continue;
      if (text.contains(term)) {
        score += term.length > 4 ? 5 : 3;
      }
    }

    return score;
  }

  Set<String> _expandedSearchTerms(String query) {
    final rawTerms = query
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((term) => term.isNotEmpty);
    final terms = <String>{query, ...rawTerms};

    for (final term in rawTerms) {
      final related = _relatedTerms[_normalize(term)] ?? const <String>[];
      terms.addAll(related.map(_normalize));
    }

    return terms;
  }

  int _scoreBook(_SunnahBook book, Set<String> terms) {
    final title = _normalize(book.title);
    final author = _normalize(book.author);
    final category = _normalize(book.category);
    final description = _normalize(book.description);
    final topics = book.topics.map(_normalize).toList();
    var score = 0;

    for (final term in terms) {
      if (title.contains(term)) score += 8;
      if (category.contains(term)) score += 5;
      if (author.contains(term)) score += 3;
      if (description.contains(term)) score += 2;
      if (topics.any((topic) => topic.contains(term) || term.contains(topic))) {
        score += 6;
      }
    }

    return score;
  }

  String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .toLowerCase()
        .trim();
  }

  bool _isDownloaded(_SunnahBook book) =>
      _storage.contains(_downloadKey(book.editionId));

  bool _isDownloading(_SunnahBook book) =>
      _downloadingEditions.contains(book.editionId);

  String _downloadKey(String editionId) => '$_downloadKeyPrefix$editionId';

  Future<void> _downloadBook(_SunnahBook book) async {
    if (_isDownloaded(book) || _isDownloading(book)) {
      return;
    }

    setState(() => _downloadingEditions.add(book.editionId));

    try {
      final response = await http
          .get(Uri.parse(book.downloadUrl))
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final hadiths = _parseHadiths(decoded);
      if (hadiths.isEmpty) {
        throw const FormatException('No hadiths found');
      }

      await _storage.write(_downloadKey(book.editionId), jsonEncode(decoded));
      await _storage.write(
        '${_downloadKey(book.editionId)}_count',
        hadiths.length,
      );
      _hadithCache[book.editionId] = hadiths;

      if (!mounted) return;
      setState(() {
        _downloadingEditions.remove(book.editionId);
      });

      MySnackbar.showSuccess(
        title: 'sunnah_book_downloaded'.tr,
        message: 'sunnah_book_download_success'.trParams({
          'book': book.title,
          'count': '${hadiths.length}',
        }),
      );
    } on TimeoutException {
      _showDownloadError(
        book,
        'sunnah_timeout_error'.tr,
      );
    } catch (_) {
      _showDownloadError(
        book,
        'sunnah_download_error'.tr,
      );
    }
  }

  void _showDownloadError(_SunnahBook book, String message) {
    if (!mounted) return;
    setState(() => _downloadingEditions.remove(book.editionId));
    MySnackbar.showError(title: book.title, message: message);
  }

  void _openBook(_SunnahBook book, {String initialQuery = ''}) {
    final rawBook = _storage.read<String>(_downloadKey(book.editionId), '');
    if (rawBook.isEmpty) {
      MySnackbar.showWarning(
        title: 'sunnah_book_not_downloaded'.tr,
        message: 'sunnah_book_not_downloaded_desc'.tr,
      );
      return;
    }

    try {
      final hadiths = _loadHadiths(book);
      if (hadiths.isEmpty) {
        throw const FormatException('No hadiths found');
      }

      Get.to(
        () => _SunnahReaderPage(
          book: book,
          hadiths: hadiths,
          initialQuery: initialQuery,
        ),
      );
    } catch (_) {
      MySnackbar.showError(
        title: book.title,
        message: 'sunnah_invalid_file_error'.tr,
      );
    }
  }

  void _deleteBook(_SunnahBook book) {
    MyDialog.show<void>(
      title: 'delete_book_title'.tr,
      content: 'delete_book_confirm'.trParams({'book': book.title}),
      confirmText: 'delete'.tr,
      cancelText: 'cancel'.tr,
      icon: Icons.delete_forever,
      onConfirm: () async {
        try {
          await _storage.remove(_downloadKey(book.editionId));
          await _storage.remove('${_downloadKey(book.editionId)}_count');
          _hadithCache.remove(book.editionId);
          setState(() {});
          MySnackbar.showSuccess(
            title: book.title,
            message: 'download_deleted_success'.tr,
          );
        } catch (_) {
          MySnackbar.showError(
            title: book.title,
            message: 'sunnah_delete_error'.tr,
          );
        }
      },
    );
  }

  List<Widget> _buildGroupedSearchResults(
      List<_GlobalHadithResult> results, Color goldColor, ThemeData theme) {
    final Map<_SunnahBook, List<_GlobalHadithResult>> grouped = {};
    for (final res in results) {
      grouped.putIfAbsent(res.book, () => []).add(res);
    }

    final widgets = <Widget>[];
    var globalIndex = 0;

    grouped.forEach((book, bookResults) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: 14.h, bottom: 8.h),
          child: Row(
            children: [
              Icon(Icons.bookmark_border, color: goldColor, size: 16.r),
              SizedBox(width: 6.w),
              Text(
                book.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

      for (final result in bookResults) {
        globalIndex++;
        final key = '${book.editionId}_${result.hadith.number}';
        final isExpanded = _expandedHadithKey == key;

        widgets.add(
          _SearchResultCard(
            result: result,
            index: globalIndex,
            isExpanded: isExpanded,
            onToggle: () {
              setState(() {
                _expandedHadithKey = _expandedHadithKey == key ? null : key;
              });
            },
            onRead: () => _openBook(result.book, initialQuery: _query),
            goldColor: goldColor,
          ),
        );
        widgets.add(SizedBox(height: 10.h));
      }
    });

    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark
        ? [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            theme.colorScheme.primary.withValues(alpha: 0.3),
          ]
        : [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.primary.withValues(alpha: 0.12),
          ];

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: headerBg,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(Icons.local_library, color: goldColor, size: 28.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sunnah_title'.tr,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'sunnah_header_desc'.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Box (submit-based)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.goldColor,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color goldColor;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: 'sunnah_search_hint'.tr,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: theme.cardTheme.color,
        prefixIcon: IconButton(
          onPressed: () => onSubmitted(controller.text),
          icon: Icon(Icons.search, color: goldColor),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    color: goldColor,
                  );
          },
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: goldColor.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: goldColor.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: goldColor, width: 1.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Result Card (expandable, grouped)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.onRead,
    required this.goldColor,
  });

  final _GlobalHadithResult result;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onRead;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = result.hadith.text;

    final displayedText = isExpanded
        ? text
        : (text.length > 150 ? '${text.substring(0, 150)}...' : text);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28.r,
                    height: 28.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: goldColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'sunnah_hadith_number_label'.trParams({'number': '${result.hadith.number}'}),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: goldColor,
                    size: 22.r,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                displayedText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.8,
                  fontSize: 18.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
              if (result.hadith.referenceLabel.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  result.hadith.referenceLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 11.sp,
                  ),
                ),
              ],
              if (isExpanded) ...[
                SizedBox(height: 12.h),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.chrome_reader_mode, size: 16),
                    label: Text('sunnah_open_in_reader'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(
                          color: goldColor.withValues(alpha: 0.55)),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 8.h),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Hint Card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHintCard extends StatelessWidget {
  const _SearchHintCard({
    required this.goldColor,
    required this.icon,
    required this.title,
    required this.text,
  });

  final Color goldColor;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: goldColor, size: 28.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Reader Page
// ─────────────────────────────────────────────────────────────────────────────

class _SunnahReaderPage extends StatefulWidget {
  const _SunnahReaderPage({
    required this.book,
    required this.hadiths,
    this.initialQuery = '',
  });

  final _SunnahBook book;
  final List<_HadithEntry> hadiths;
  final String initialQuery;

  @override
  State<_SunnahReaderPage> createState() => _SunnahReaderPageState();
}

class _SunnahReaderPageState extends State<_SunnahReaderPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int? _expandedHadithNumber;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController.text = widget.initialQuery;
    _searchController.addListener(() {
      if (_searchController.text.trim().isEmpty && _query.isNotEmpty) {
        setState(() {
          _query = '';
          _expandedHadithNumber = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final results = _filteredHadiths();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          bottomNavigationBar: const AppBottomNav(currentIndex: 3),
          appBar: AppBar(
            title: Text(widget.book.title),
            centerTitle: false,
            actions: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12.w),
                child: Center(
                  child: Text(
                    'sunnah_hadiths_count_label'.trParams({'count': '${widget.hadiths.length}'}),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ArabesqueBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            setState(() {
                              _query = value;
                              _expandedHadithNumber = null;
                            });
                            FocusScope.of(context).unfocus();
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'sunnah_search_inside_book'.trParams({'book': widget.book.title}),
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.cardTheme.color,
                            prefixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _query = _searchController.text;
                                  _expandedHadithNumber = null;
                                });
                                FocusScope.of(context).unfocus();
                              },
                              icon: Icon(Icons.search, color: goldColor),
                            ),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                return value.text.isEmpty
                                    ? const SizedBox.shrink()
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _query = '';
                                            _expandedHadithNumber = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                        color: goldColor,
                                      );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18.r),
                              borderSide: BorderSide(
                                color: goldColor.withValues(alpha: 0.18),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18.r),
                              borderSide: BorderSide(
                                color: goldColor.withValues(alpha: 0.18),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18.r),
                              borderSide: BorderSide(
                                color: goldColor,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Icon(
                              Icons.chrome_reader_mode,
                              color: goldColor,
                              size: 18.r,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _query.trim().isEmpty
                                  ? 'sunnah_saved_hadiths'.tr
                                  : 'sunnah_search_results'.tr,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: goldColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${results.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: results.isEmpty
                        ? ListView(
                            padding: EdgeInsets.symmetric(horizontal: 18.w),
                            children: [_EmptySearch(goldColor: goldColor)],
                          )
                        : ListView.separated(
                            padding:
                                EdgeInsets.fromLTRB(18.w, 0, 18.w, 28.h),
                            physics: const BouncingScrollPhysics(),
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final hadith = results[index];
                              final isExpanded = _expandedHadithNumber == hadith.number;
                              return _HadithCard(
                                hadith: hadith,
                                goldColor: goldColor,
                                index: index + 1,
                                isExpanded: isExpanded,
                                onTap: () {
                                  setState(() {
                                    _expandedHadithNumber = isExpanded ? null : hadith.number;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_HadithEntry> _filteredHadiths() {
    final query = _normalize(_query);
    if (query.isEmpty) {
      return widget.hadiths;
    }
    return widget.hadiths
        .where((hadith) => _normalize(hadith.searchText).contains(query))
        .toList();
  }

  String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .toLowerCase()
        .trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hadith Card
// ─────────────────────────────────────────────────────────────────────────────

class _HadithCard extends StatelessWidget {
  const _HadithCard({
    required this.hadith,
    required this.goldColor,
    this.index,
    required this.isExpanded,
    required this.onTap,
  });

  final _HadithEntry hadith;
  final Color goldColor;
  final int? index;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = hadith.text;
    final displayedText = isExpanded
        ? text
        : (text.length > 150 ? '${text.substring(0, 150)}...' : text);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (index != null) ...[
                    Container(
                      width: 28.r,
                      height: 28.r,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                         color: goldColor.withValues(alpha: 0.12),
                         shape: BoxShape.circle,
                         border: Border.all(
                             color: goldColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '$index',
                        style: TextStyle(
                          color: goldColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'sunnah_hadith_label'.trParams({'number': '${hadith.number}'}),
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hadith.bookNumber != null ||
                      hadith.referenceNumber != null) ...[
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        hadith.referenceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (text.length > 150) ...[
                    SizedBox(width: 8.w),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: goldColor,
                      size: 22.r,
                    ),
                  ],
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                displayedText,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.85,
                  fontSize: 21.sp,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book Card
// ─────────────────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.goldColor,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.onRead,
    required this.onDelete,
  });

  final _SunnahBook book;
  final Color goldColor;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46.r,
                height: 54.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12.r),
                  border:
                      Border.all(color: goldColor.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.menu_book, color: goldColor, size: 24.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  book.category,
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            book.description,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final topic in book.topics.take(5))
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    topic,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.brightness == Brightness.dark
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              if (downloaded) ...[
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('delete'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.chrome_reader_mode),
                    label: Text('sunnah_read_book'.tr),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSecondary,
                      backgroundColor: goldColor,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      elevation: 0,
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: downloading ? () {} : onDownload,
                    icon: downloading
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: goldColor,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(downloading ? 'downloading'.tr : 'download'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(
                        color: goldColor.withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Search
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(Icons.manage_search, color: goldColor, size: 42.r),
          SizedBox(height: 10.h),
          Text(
            'sunnah_no_results'.tr,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'sunnah_no_results_desc'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading More Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18.r,
            height: 18.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: goldColor.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            'sunnah_scroll_for_more'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: goldColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _SunnahBook {
  const _SunnahBook({
    required this.titleKey,
    required this.authorKey,
    required this.categoryKey,
    required this.descriptionKey,
    required this.bookKey,
    required this.topicsKeys,
  });

  final String titleKey;
  final String authorKey;
  final String categoryKey;
  final String descriptionKey;
  final String bookKey;
  final List<String> topicsKeys;

  String get title => titleKey.tr;
  String get author => authorKey.tr;
  String get category => categoryKey.tr;
  String get description => descriptionKey.tr;
  List<String> get topics => topicsKeys.map((k) => k.tr).toList();

  String get editionId {
    final lang = Get.locale?.languageCode ?? 'ar';
    final prefix = lang == 'en' ? 'eng' : 'ara';
    return '$prefix-$bookKey';
  }

  String get downloadUrl =>
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$editionId.min.json';
}

class _HadithEntry {
  const _HadithEntry({
    required this.number,
    required this.text,
    this.bookNumber,
    this.referenceNumber,
  });

  final int number;
  final String text;
  final int? bookNumber;
  final int? referenceNumber;

  String get referenceLabel {
    final parts = <String>[];
    if (bookNumber != null) {
      parts.add('sunnah_book_no'.trParams({'number': '$bookNumber'}));
    }
    if (referenceNumber != null) {
      parts.add('sunnah_number_no'.trParams({'number': '$referenceNumber'}));
    }
    return parts.join(' - ');
  }

  String get searchText => '$number $referenceLabel $text';
}

class _GlobalHadithResult {
  const _GlobalHadithResult({required this.book, required this.hadith});

  final _SunnahBook book;
  final _HadithEntry hadith;
}

class _ScoredGlobalHadithResult {
  const _ScoredGlobalHadithResult({required this.result, required this.score});

  final _GlobalHadithResult result;
  final int score;
}

// ─────────────────────────────────────────────────────────────────────────────
// Parsing helpers
// ─────────────────────────────────────────────────────────────────────────────

List<_HadithEntry> _parseHadiths(dynamic decoded) {
  if (decoded is! Map || decoded['hadiths'] is! List) {
    return const <_HadithEntry>[];
  }

  return (decoded['hadiths'] as List)
      .whereType<Map>()
      .map((item) {
        final reference = item['reference'];
        return _HadithEntry(
          number:
              _readInt(item['arabicnumber']) ??
              _readInt(item['hadithnumber']) ??
              0,
          text: _cleanHadithText(item['text']?.toString() ?? ''),
          bookNumber: reference is Map ? _readInt(reference['book']) : null,
          referenceNumber: reference is Map
              ? _readInt(reference['hadith'])
              : null,
        );
      })
      .where((hadith) => hadith.text.isNotEmpty)
      .toList(growable: false);
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _cleanHadithText(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>',  caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
