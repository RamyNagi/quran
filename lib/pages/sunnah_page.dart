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
  final Set<String> _downloadedEditions = <String>{};
  final Set<String> _downloadingEditions = <String>{};
  final Map<String, List<_HadithEntry>> _hadithCache = {};

  // Lazy-loading for global search results
  List<_GlobalHadithResult> _cachedHadithResults = [];
  int _visibleHadithCount = 30;

  static final List<_SunnahBook> _books = [
    _SunnahBook(
      title: 'صحيح البخاري',
      author: 'الإمام محمد بن إسماعيل البخاري',
      category: 'الصحيحان',
      description:
          'أصح كتب الحديث، مرتب على كتب فقهية ويضم أبواب الإيمان والعبادات والمعاملات والسير.',
      editionId: 'ara-bukhari',
      topics: [
        'الإيمان',
        'الوضوء',
        'الصلاة',
        'الزكاة',
        'الصيام',
        'الحج',
        'البيوع',
        'النكاح',
        'الجهاد',
        'الأدب',
      ],
    ),
    _SunnahBook(
      title: 'صحيح مسلم',
      author: 'الإمام مسلم بن الحجاج النيسابوري',
      category: 'الصحيحان',
      description:
          'من أوثق دواوين السنة، يتميز بجمع طرق الحديث في موضع واحد وسهولة تتبع الروايات.',
      editionId: 'ara-muslim',
      topics: [
        'الإيمان',
        'الطهارة',
        'الصلاة',
        'الجنائز',
        'الزكاة',
        'الصيام',
        'الحج',
        'القدر',
        'البر',
      ],
    ),
    _SunnahBook(
      title: 'سنن أبي داود',
      author: 'الإمام أبو داود السجستاني',
      category: 'السنن',
      description:
          'كتاب عظيم في أحاديث الأحكام، مناسب للبحث في مسائل الفقه والعمل اليومي.',
      editionId: 'ara-abudawud',
      topics: [
        'الطهارة',
        'الصلاة',
        'الزكاة',
        'الصوم',
        'المناسك',
        'النكاح',
        'الطلاق',
        'البيوع',
        'الأقضية',
      ],
    ),
    _SunnahBook(
      title: 'جامع الترمذي',
      author: 'الإمام محمد بن عيسى الترمذي',
      category: 'السنن',
      description:
          'يجمع الأحاديث مع بيان درجتها وكلام أهل العلم، وفيه أبواب الفضائل والآداب.',
      editionId: 'ara-tirmidhi',
      topics: [
        'الطهارة',
        'الصلاة',
        'الوتر',
        'الرضاع',
        'البيوع',
        'الأحكام',
        'الفضائل',
        'الدعوات',
        'الأدب',
      ],
    ),
    _SunnahBook(
      title: 'سنن النسائي',
      author: 'الإمام أحمد بن شعيب النسائي',
      category: 'السنن',
      description:
          'من كتب السنن المعتمدة، مشهور بدقة الاختيار وكثرة أبواب العبادات والمعاملات.',
      editionId: 'ara-nasai',
      topics: [
        'الطهارة',
        'المواقيت',
        'الصلاة',
        'الجنائز',
        'الصيام',
        'الحج',
        'النكاح',
        'الزينة',
      ],
    ),
    _SunnahBook(
      title: 'سنن ابن ماجه',
      author: 'الإمام محمد بن يزيد ابن ماجه',
      category: 'السنن',
      description:
          'آخر الكتب الستة، وفيه أبواب نافعة في السنن والفتن والزهد والأطعمة والطب.',
      editionId: 'ara-ibnmajah',
      topics: [
        'المقدمة',
        'الطهارة',
        'الصلاة',
        'الزكاة',
        'الصيام',
        'التجارات',
        'الأطعمة',
        'الطب',
        'الزهد',
      ],
    ),
    _SunnahBook(
      title: 'موطأ الإمام مالك',
      author: 'الإمام مالك بن أنس',
      category: 'الموطآت',
      description:
          'من أقدم دواوين السنة والفقه، يجمع الحديث وآثار الصحابة وعمل أهل المدينة.',
      editionId: 'ara-malik',
      topics: [
        'الطهارة',
        'الصلاة',
        'القرآن',
        'الزكاة',
        'الصيام',
        'الحج',
        'النذور',
        'الأقضية',
      ],
    ),
    _SunnahBook(
      title: 'الأحاديث القدسية الأربعون',
      author: 'جمع وترتيب من كتب الحديث',
      category: 'المتون المختصرة',
      description:
          'مجموعة نافعة من الأحاديث القدسية، مناسبة للقراءة والتأمل داخل التطبيق.',
      editionId: 'ara-qudsi',
      topics: [
        'الإيمان',
        'الإخلاص',
        'التوبة',
        'الرحمة',
        'الدعاء',
        'الذكر',
        'التقوى',
      ],
    ),
    _SunnahBook(
      title: 'الأربعون النووية',
      author: 'الإمام يحيى بن شرف النووي',
      category: 'المتون المختصرة',
      description:
          'أحاديث جامعة لأصول الدين والعمل، تصلح كبداية ممتازة لحفظ وفهم السنة.',
      editionId: 'ara-nawawi',
      topics: [
        'النية',
        'الإسلام',
        'الإيمان',
        'الإحسان',
        'الحلال',
        'الحرام',
        'النصيحة',
        'الأخلاق',
      ],
    ),
    _SunnahBook(
      title: 'الأربعون للدهلوي',
      author: 'الإمام شاه ولي الله الدهلوي',
      category: 'المتون المختصرة',
      description:
          'أربعون حديثا مختارة في أصول الإيمان والعمل والتزكية، مناسبة للحفظ والمراجعة.',
      editionId: 'ara-dehlawi',
      topics: [
        'الإيمان',
        'العلم',
        'الأخلاق',
        'العبادة',
        'التزكية',
        'السلوك',
        'الآداب',
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
    _downloadedEditions.addAll(
      _books
          .where((book) => _storage.contains(_downloadKey(book.editionId)))
          .map((book) => book.editionId),
    );
    _scrollController.addListener(_onScroll);
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
                              'نتائج البحث العام (${_cachedHadithResults.length} نتيجة)',
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
                      if (_downloadedEditions.isEmpty)
                        _SearchHintCard(
                          goldColor: goldColor,
                          icon: Icons.download,
                          title: 'حمّل كتابا أولا',
                          text:
                              'البحث العام داخل نصوص الأحاديث يعمل على الكتب المحملة داخل التطبيق.',
                        )
                      else if (_cachedHadithResults.isEmpty)
                        _SearchHintCard(
                          goldColor: goldColor,
                          icon: Icons.manage_search,
                          title: 'لا توجد أحاديث مطابقة',
                          text: 'جرّب كلمة أخرى أو حمّل كتبا أكثر لتوسيع البحث.',
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
                                'انتهت النتائج',
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
                            'أشهر كتب السنة',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: goldColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${results.length} كتاب',
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
    if (normalizedQuery.isEmpty || _downloadedEditions.isEmpty) {
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
      _downloadedEditions.contains(book.editionId);

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
        _downloadedEditions.add(book.editionId);
      });

      MySnackbar.showSuccess(
        title: 'تم تحميل الكتاب',
        message: '${book.title} - ${hadiths.length} حديث محفوظ داخل التطبيق',
      );
    } on TimeoutException {
      _showDownloadError(
        book,
        'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    } catch (_) {
      _showDownloadError(
        book,
        'تعذر تحميل الكتاب الآن. تحقق من الاتصال وحاول لاحقا.',
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
        title: 'الكتاب غير محمل',
        message: 'حمّل الكتاب أولا ثم افتحه للقراءة داخل التطبيق.',
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
        message: 'الملف المحفوظ غير صالح. أعد تحميل الكتاب مرة أخرى.',
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
          setState(() {
            _downloadedEditions.remove(book.editionId);
          });
          MySnackbar.showSuccess(
            title: book.title,
            message: 'download_deleted_success'.tr,
          );
        } catch (_) {
          MySnackbar.showError(
            title: book.title,
            message: 'تعذر حذف الكتاب حالياً.',
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
                  'السنة الشريفة',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'مكتبة مختارة لأهم كتب الحديث مع بحث سريع حسب الموضوع أو اسم الكتاب.',
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
        hintText: 'ابحث عن موضوع: الصلاة، النية، البيوع...',
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
                    'حديث رقم ${result.hadith.number}',
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
                  height: 1.5,
                  fontSize: 14.sp,
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
                    label: const Text('فتح في القارئ'),
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

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController.text = widget.initialQuery;
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
          appBar: AppBar(
            title: Text(widget.book.title),
            centerTitle: false,
            actions: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 12.w),
                child: Center(
                  child: Text(
                    '${widget.hadiths.length} حديث',
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
                            setState(() => _query = value);
                            FocusScope.of(context).unfocus();
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ابحث داخل ${widget.book.title}',
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.cardTheme.color,
                            prefixIcon: IconButton(
                              onPressed: () {
                                setState(() => _query = _searchController.text);
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
                                          setState(() => _query = '');
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
                                  ? 'الأحاديث المحفوظة'
                                  : 'نتائج البحث',
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
                            itemBuilder: (context, index) => _HadithCard(
                              hadith: results[index],
                              goldColor: goldColor,
                            ),
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
  const _HadithCard({required this.hadith, required this.goldColor});

  final _HadithEntry hadith;
  final Color goldColor;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'حديث ${hadith.number}',
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
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            hadith.text,
            textAlign: TextAlign.start,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.85,
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: downloading
                      ? () {}
                      : (downloaded ? onDelete : onDownload),
                  icon: downloading
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: goldColor,
                          ),
                        )
                      : Icon(
                          downloaded
                              ? Icons.delete_outline
                              : Icons.download,
                        ),
                  label: Text(
                    downloading
                        ? 'downloading'.tr
                        : (downloaded ? 'delete'.tr : 'download'.tr),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        downloaded ? theme.colorScheme.error : goldColor,
                    side: BorderSide(
                      color: downloaded
                          ? theme.colorScheme.error.withValues(alpha: 0.7)
                          : goldColor.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              IconButton.filledTonal(
                onPressed: downloaded ? onRead : null,
                icon: const Icon(Icons.chrome_reader_mode),
                style: IconButton.styleFrom(
                  foregroundColor: goldColor,
                  backgroundColor: goldColor.withValues(alpha: 0.12),
                ),
              ),
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
            'لا توجد نتائج مطابقة',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'جرب كلمة أقرب مثل: الطهارة، الصيام، الأدب، أو اسم الكتاب.',
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
            'استمر في التمرير لمزيد من النتائج...',
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
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.editionId,
    required this.topics,
  });

  final String title;
  final String author;
  final String category;
  final String description;
  final String editionId;
  final List<String> topics;

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
      parts.add('كتاب $bookNumber');
    }
    if (referenceNumber != null) {
      parts.add('رقم $referenceNumber');
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
