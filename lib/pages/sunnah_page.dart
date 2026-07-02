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

class SunnahPage extends StatefulWidget {
  const SunnahPage({super.key});

  @override
  State<SunnahPage> createState() => _SunnahPageState();
}

class _SunnahPageState extends State<SunnahPage> {
  static const String _downloadKeyPrefix = 'sunnah_book_json_';

  final TextEditingController _searchController = TextEditingController();
  late final StorageService _storage;
  String _query = '';
  final Set<String> _downloadedEditions = <String>{};
  final Set<String> _downloadingEditions = <String>{};
  final Map<String, List<_HadithEntry>> _hadithCache = {};

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);
    final results = _filteredBooks();
    final hadithResults = _globalHadithResults();
    final hasSearch = _query.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: ArabesqueBackground(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 104.h),
              physics: const BouncingScrollPhysics(),
              children: [
                _Header(goldColor: goldColor),
                SizedBox(height: 18.h),
                _SearchBox(
                  controller: _searchController,
                  goldColor: goldColor,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                SizedBox(height: 16.h),
                _TopicChips(
                  goldColor: goldColor,
                  onSelected: (topic) {
                    _searchController.text = topic;
                    setState(() => _query = topic);
                  },
                ),
                SizedBox(height: 22.h),
                _FeaturedCard(
                  goldColor: goldColor,
                  downloaded: _isDownloaded(_books.first),
                  downloading: _isDownloading(_books.first),
                  onDownload: () => _downloadBook(_books.first),
                  onRead: () => _openBook(_books.first),
                ),
                SizedBox(height: 22.h),
                if (hasSearch) ...[
                  _GlobalSearchSection(
                    query: _query,
                    results: hadithResults,
                    downloadedCount: _downloadedEditions.length,
                    goldColor: goldColor,
                    onOpenResult: (result) =>
                        _openBook(result.book, initialQuery: _query),
                  ),
                  SizedBox(height: 22.h),
                ],
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: goldColor, size: 18.r),
                    SizedBox(width: 8.w),
                    Text(
                      _query.trim().isEmpty
                          ? 'أشهر كتب السنة'
                          : 'نتائج البحث الذكي',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: goldColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasSearch
                          ? '${results.length} كتاب مطابق'
                          : '${results.length} كتاب',
                      style: theme.textTheme.bodySmall,
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
                    ),
                    SizedBox(height: 12.h),
                  ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 3),
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

  List<_GlobalHadithResult> _globalHadithResults() {
    final normalizedQuery = _normalize(_query);
    if (normalizedQuery.isEmpty || _downloadedEditions.isEmpty) {
      return const <_GlobalHadithResult>[];
    }

    final terms = _expandedSearchTerms(normalizedQuery);
    final results = <_ScoredGlobalHadithResult>[];

    for (final book in _books.where(_isDownloaded)) {
      final hadiths = _loadHadiths(book);
      for (final hadith in hadiths) {
        final score = _scoreHadith(hadith, terms);
        if (score > 0) {
          results.add(
            _ScoredGlobalHadithResult(
              result: _GlobalHadithResult(book: book, hadith: hadith),
              score: score,
            ),
          );
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results
        .take(30)
        .map((scored) => scored.result)
        .toList(growable: false);
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
    MySnackbar.showError(
      title: book.title,
      message: message,
    );
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
}

class _Header extends StatelessWidget {
  const _Header({required this.goldColor});

  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
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
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'مكتبة مختارة لأهم كتب الحديث مع بحث سريع حسب الموضوع أو اسم الكتاب.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.goldColor,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color goldColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'ابحث عن موضوع: الصلاة، النية، البيوع...',
        hintStyle: theme.textTheme.bodySmall,
        filled: true,
        fillColor: theme.cardTheme.color,
        prefixIcon: Icon(Icons.search, color: goldColor),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                color: goldColor,
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

class _TopicChips extends StatelessWidget {
  const _TopicChips({required this.goldColor, required this.onSelected});

  final Color goldColor;
  final ValueChanged<String> onSelected;

  static const List<String> topics = [
    'الصلاة',
    'الوضوء',
    'الصيام',
    'الأخلاق',
    'النية',
    'البيوع',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final topic in topics)
          ActionChip(
            onPressed: () => onSelected(topic),
            avatar: Icon(Icons.tag, size: 16.r, color: goldColor),
            label: Text(topic),
            labelStyle: TextStyle(color: goldColor, fontSize: 12.sp),
            backgroundColor: goldColor.withValues(alpha: 0.09),
            side: BorderSide(color: goldColor.withValues(alpha: 0.18)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.goldColor,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.onRead,
  });

  final Color goldColor;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            goldColor.withValues(alpha: 0.26),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.52),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: goldColor),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'اختيار مقترح للبداية',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: goldColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'ابدأ بالصحيحين ثم السنن الأربعة، وبعدها انتقل للمتون المختصرة مثل الأربعين النووية والقدسية.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(downloaded ? Icons.download_done : Icons.download),
                  label: Text(downloaded ? 'محمل' : 'تحميل صحيح البخاري'),
                  style: FilledButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              if (downloaded) ...[
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.chrome_reader_mode),
                    label: const Text('قراءة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(
                        color: goldColor.withValues(alpha: 0.55),
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

class _GlobalSearchSection extends StatelessWidget {
  const _GlobalSearchSection({
    required this.query,
    required this.results,
    required this.downloadedCount,
    required this.goldColor,
    required this.onOpenResult,
  });

  final String query;
  final List<_GlobalHadithResult> results;
  final int downloadedCount;
  final Color goldColor;
  final ValueChanged<_GlobalHadithResult> onOpenResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.travel_explore, color: goldColor, size: 18.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'بحث في الكتب المحملة',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('${results.length} نتيجة', style: theme.textTheme.bodySmall),
          ],
        ),
        SizedBox(height: 10.h),
        if (downloadedCount == 0)
          _SearchHintCard(
            goldColor: goldColor,
            icon: Icons.download,
            title: 'حمّل كتابا أولا',
            text:
                'البحث العام داخل نصوص الأحاديث يعمل على الكتب المحملة داخل التطبيق.',
          )
        else if (results.isEmpty)
          _SearchHintCard(
            goldColor: goldColor,
            icon: Icons.manage_search,
            title: 'لا توجد أحاديث مطابقة',
            text: 'جرّب كلمة أخرى أو حمّل كتبا أكثر لتوسيع البحث.',
          )
        else
          for (final result in results.take(6)) ...[
            _GlobalHadithResultCard(
              result: result,
              query: query,
              goldColor: goldColor,
              onTap: () => onOpenResult(result),
            ),
            SizedBox(height: 10.h),
          ],
        if (results.length > 6)
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Text(
              'يعرض أهم 6 نتائج هنا. افتح الكتاب لمتابعة بقية النتائج بنفس البحث.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _GlobalHadithResultCard extends StatelessWidget {
  const _GlobalHadithResultCard({
    required this.result,
    required this.query,
    required this.goldColor,
    required this.onTap,
  });

  final _GlobalHadithResult result;
  final String query;
  final Color goldColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
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
                Icon(Icons.menu_book, color: goldColor, size: 18.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    result.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'حديث ${result.hadith.number}',
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _snippet(result.hadith.text, query),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _snippet(String text, String query) {
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedText = _normalizeLoose(trimmed);
    final normalizedQuery = _normalizeLoose(query);
    final index = normalizedQuery.isEmpty
        ? -1
        : normalizedText.indexOf(normalizedQuery);

    if (index <= 35) {
      return trimmed.length <= 220
          ? trimmed
          : '${trimmed.substring(0, 220)}...';
    }

    final start = (index - 70).clamp(0, trimmed.length);
    final end = (start + 220).clamp(0, trimmed.length);
    return '...${trimmed.substring(start, end)}...';
  }

  String _normalizeLoose(String value) {
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
}

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
                  ),
                ),
                SizedBox(height: 4.h),
                Text(text, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);
    final results = _filteredHadiths();

    return Directionality(
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
                  style: theme.textTheme.bodySmall,
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
                        onChanged: (value) => setState(() => _query = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'ابحث داخل ${widget.book.title}',
                          hintStyle: theme.textTheme.bodySmall,
                          filled: true,
                          fillColor: theme.cardTheme.color,
                          prefixIcon: Icon(Icons.search, color: goldColor),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close),
                                  color: goldColor,
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
                            style: theme.textTheme.bodySmall,
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
                          padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 28.h),
                          physics: const BouncingScrollPhysics(),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12.h),
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
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
                    style: theme.textTheme.bodySmall,
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
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.goldColor,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    required this.onRead,
  });

  final _SunnahBook book;
  final Color goldColor;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onRead;

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
                  border: Border.all(color: goldColor.withValues(alpha: 0.22)),
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
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final topic in book.topics.take(5))
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(topic, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(downloaded ? Icons.download_done : Icons.download),
                  label: Text(downloaded ? 'محمل داخل التطبيق' : 'تحميل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldColor,
                    side: BorderSide(color: goldColor.withValues(alpha: 0.55)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              IconButton.filledTonal(
                onPressed: downloaded ? onRead : null,
                icon: const Icon(Icons.chrome_reader_mode),
                color: goldColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'جرب كلمة أقرب مثل: الطهارة، الصيام، الأدب، أو اسم الكتاب.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

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
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
