// lib/utils/csv_downloader_web.dart
// This version runs on WEB (Chrome) — uses browser download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadCSV(String csv, String fileName) async {
  final blob = html.Blob([csv], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
