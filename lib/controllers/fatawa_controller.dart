import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../static/mysnakbar.dart';

class FatwaResult {
  const FatwaResult({
    required this.id,
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String id;
  final String title;
  final String url;
  final String snippet;
}

class FatawaController extends GetxController {
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final query = ''.obs;
  final results = <FatwaResult>[].obs;
  final searchController = TextEditingController();
  final isServiceStopped = false.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      if (searchController.text.trim().isEmpty && query.value.isNotEmpty) {
        query.value = '';
        results.clear();
        errorMessage.value = '';
      }
    });
    checkServiceStatus();
  }

  Future<void> checkServiceStatus() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.islamweb.net/ar/fatwa/?page=websearch&stxt=%D8%B5%D9%84%D8%A7%D8%A9'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept-Language': 'ar,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        isServiceStopped.value = true;
        return;
      }

      final doc = parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
      final hasResults = doc.querySelectorAll('ul.search-results > li').isNotEmpty || 
                         doc.querySelectorAll('a').any((link) {
                           final href = link.attributes['href'] ?? '';
                           return href.contains('/fatwa/') || href.contains('/ar/fatwa/');
                         });

      isServiceStopped.value = !hasResults;
    } catch (_) {
      // Temporary network error, do not block the UI unless it definitely fails
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> performSearch(String queryText) async {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return;

    // Dismiss keyboard automatically
    FocusManager.instance.primaryFocus?.unfocus();

    // Check internet connection before making the request
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No Internet Connection');
      }
    } catch (_) {
      MySnackbar.showError(
        title: 'no_internet_title'.tr,
        message: 'fatwa_no_internet_alert'.tr,
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    query.value = trimmed;
    results.clear();

    try {
      final response = await http.get(
        Uri.parse('https://www.islamweb.net/ar/fatwa/?page=websearch&stxt=${Uri.encodeComponent(trimmed)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept-Language': 'ar,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}');
      }

      final document = parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
      final seenIds = <String>{};
      final list = <FatwaResult>[];

      final resultItems = document.querySelectorAll('ul.search-results > li');
      if (resultItems.isNotEmpty) {
        for (final item in resultItems) {
          final titleLink = item.querySelector('h5 a') ?? item.querySelector('a');
          if (titleLink == null) continue;

          final href = titleLink.attributes['href'] ?? '';
          final idMatch = RegExp(r'/fatwa/(\d+)').firstMatch(href);
          if (idMatch != null) {
            final id = idMatch.group(1)!;
            if (seenIds.contains(id)) continue;
            seenIds.add(id);

            var title = titleLink.text.trim();
            if (title.isEmpty) continue;
            title = title.replaceAll(RegExp(r'\s+'), ' ');

            final descEl = item.querySelector('div.desc') ?? item.querySelector('p');
            var snippet = descEl?.text.trim() ?? '';
            snippet = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (snippet.length > 150) {
              snippet = '${snippet.substring(0, 150)}...';
            }

            var url = href;
            if (!url.startsWith('http')) {
              url = 'https://www.islamweb.net$url';
            }

            list.add(FatwaResult(
              id: id,
              title: title,
              url: url,
              snippet: snippet,
            ));
          }
        }
      } else {
        // Fallback if structure changes: search all links
        final links = document.querySelectorAll('a');
        for (final link in links) {
          final href = link.attributes['href'] ?? '';
          if (href.contains('/fatwa/') || href.contains('/ar/fatwa/')) {
            final idMatch = RegExp(r'/fatwa/(\d+)').firstMatch(href);
            if (idMatch != null) {
              final id = idMatch.group(1)!;
              if (seenIds.contains(id)) continue;
              seenIds.add(id);

              var title = link.text.trim();
              if (title.isEmpty) continue;
              title = title.replaceAll(RegExp(r'\s+'), ' ');

              var snippet = '';
              var parent = link.parent;
              while (parent != null && parent.localName != 'li' && parent.localName != 'div') {
                parent = parent.parent;
              }
              if (parent != null) {
                final pTags = parent.querySelectorAll('p');
                for (final p in pTags) {
                  final txt = p.text.trim();
                  if (txt.isNotEmpty && !txt.contains(title)) {
                    snippet = txt.replaceAll(RegExp(r'\s+'), ' ');
                    break;
                  }
                }
              }

              var url = href;
              if (!url.startsWith('http')) {
                url = 'https://www.islamweb.net$url';
              }

              list.add(FatwaResult(
                id: id,
                title: title,
                url: url,
                snippet: snippet,
              ));
            }
          }
        }
      }

      if (list.isEmpty) {
        try {
          final testResponse = await http.get(
            Uri.parse('https://www.islamweb.net/ar/fatwa/?page=websearch&stxt=%D8%B5%D9%84%D8%A7%D8%A9'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept-Language': 'ar,en;q=0.9',
            },
          ).timeout(const Duration(seconds: 5));
          final testDoc = parser.parse(utf8.decode(testResponse.bodyBytes, allowMalformed: true));
          final hasResults = testDoc.querySelectorAll('ul.search-results > li').isNotEmpty || 
                             testDoc.querySelectorAll('a').any((link) {
                               final href = link.attributes['href'] ?? '';
                               return href.contains('/fatwa/') || href.contains('/ar/fatwa/');
                             });
          if (!hasResults) {
            isServiceStopped.value = true;
            errorMessage.value = 'fatwa_service_stopped'.tr;
            isLoading.value = false;
            return;
          }
        } catch (_) {}
      }

      results.assignAll(list);
      isLoading.value = false;
    } on TimeoutException {
      isLoading.value = false;
      errorMessage.value = 'sunnah_timeout_error'.tr;
    } catch (e) {
      isLoading.value = false;
      isServiceStopped.value = true;
      errorMessage.value = 'fatwa_service_stopped'.tr;
    }
  }

  Future<Map<String, String>> fetchFatwaDetails(String url, String title) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept-Language': 'ar,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Server returned status ${response.statusCode}');
    }

    final document = parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));

    // Clean up script, style, noscript, and iframe tags to avoid raw JS/CSS/advertisement texts
    document.querySelectorAll('script').forEach((el) => el.remove());
    document.querySelectorAll('style').forEach((el) => el.remove());
    document.querySelectorAll('noscript').forEach((el) => el.remove());
    document.querySelectorAll('iframe').forEach((el) => el.remove());

    var qText = '';
    var aText = '';

    // Try Schema.org SEO-stable selectors first
    final schemaQ = document.querySelector('[itemprop="mainEntity"] [itemprop="text"]') ??
                    document.querySelector('[itemprop="mainEntity"]');
    if (schemaQ != null) {
      qText = schemaQ.text.trim();
    }

    final schemaA = document.querySelector('[itemprop="acceptedAnswer"] [itemprop="text"]') ??
                    document.querySelector('[itemprop="acceptedAnswer"]') ??
                    document.querySelector('.mainitem.quest-fatwa') ??
                    document.querySelector('.quest-fatwa');
    if (schemaA != null) {
      aText = schemaA.text.trim();
    }

    // Fallback 1: specific CSS classes used by Islamweb
    if (qText.isEmpty) {
      final qEl = document.querySelector('.calssfatwaques') ??
                  document.querySelector('.fatwa-q') ??
                  document.querySelector('.question');
      if (qEl != null) qText = qEl.text.trim();
    }

    if (aText.isEmpty) {
      final aEl = document.querySelector('.calssfatwaans') ??
                  document.querySelector('.fatwa-a') ??
                  document.querySelector('.answer');
      if (aEl != null) aText = aEl.text.trim();
    }

    // Fallback 2: parse by label text
    if (qText.isEmpty || aText.isEmpty) {
      final elements = document.querySelectorAll('div, section, p, h1, h2');
      for (final el in elements) {
        final text = el.text.trim();
        if (text.startsWith('السؤال:') && qText.isEmpty) {
          qText = text.replaceFirst('السؤال:', '').trim();
        } else if ((text.startsWith('الفتوى:') || text.startsWith('الجواب:') || text.startsWith('الإجابة:')) && aText.isEmpty) {
          aText = text.replaceFirst(RegExp(r'^(الفتوى:|الجواب:|الإجابة:)'), '').trim();
        }
      }
    }

    // Fallback 3: Document-wide fallback if elements are still empty
    if (qText.isEmpty) {
      qText = title;
    }
    if (aText.isEmpty) {
      final mainEl = document.querySelector('article') ??
                     document.querySelector('.main-content');
      if (mainEl != null) {
        aText = mainEl.text.trim();
      } else {
        // Fallback to body but try to extract clean text without footer/header links
        final bodyClone = document.body?.clone(true);
        if (bodyClone != null) {
          bodyClone.querySelectorAll('header, footer, nav, .footer, .header, #footer, #header, .sidebar, #sidebar, .aside, .menu').forEach((el) => el.remove());
          aText = bodyClone.text.trim();
        }
      }

      if (aText.length > 3000) {
        aText = '${aText.substring(0, 3000)}...';
      }
    }

    qText = qText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    aText = aText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return {
      'question': qText,
      'answer': aText,
    };
  }
}
