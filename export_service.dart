// lib/services/export_service.dart
// Infrastructure: File system operations, PDF generation, sharing

import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/chat_message.dart';

class ExportService {
  static Future<void> exportAsTxt(
      List<ChatMessage> messages, String userName) async {
    try {
      final content = StringBuffer();
      content.writeln('AI Chat History - $userName');
      content.writeln(
          'Export Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      content.writeln('=' * 50);
      content.writeln();

      for (final msg in messages) {
        final sender = msg.isUser ? userName : (msg.model ?? 'AI Assistant');
        content.writeln('[$sender - ${msg.formattedTime}]');
        if (msg.imageUrl != null) {
          content.writeln('[Image Attached: ${msg.imageUrl!.split('/').last}]');
        }
        content.writeln(msg.text);
        content.writeln('-' * 30);
      }

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(content.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat Export - $userName',
        text:
            'Here is my AI chat export from ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      throw Exception('Failed to export as TXT: $e');
    }
  }

  static Future<void> exportAsPdf(
      List<ChatMessage> messages, String userName) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'AI Chat History',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('User: $userName'),
                pw.Text(
                    'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                pw.Divider(),
                pw.SizedBox(height: 20),
                ...messages.map((msg) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${msg.isUser ? userName : (msg.model ?? 'AI Assistant')} - ${msg.formattedTime}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        if (msg.imageUrl != null)
                          pw.Text(
                            '[Image Attached: ${msg.imageUrl!.split('/').last}]',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.blue),
                          ),
                        pw.Text(
                          msg.text,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat PDF Export - $userName',
      );
    } catch (e) {
      throw Exception('Failed to export as PDF: $e');
    }
  }

  static Future<void> exportAsJson(
      List<ChatMessage> messages, String userName) async {
    try {
      final data = {
        'user': userName,
        'export_date': DateTime.now().toIso8601String(),
        'message_count': messages.length,
        'messages': messages
            .map((m) => {
                  'id': m.id,
                  'text': m.text,
                  'isUser': m.isUser,
                  'timestamp': m.timestamp.toIso8601String(),
                  'model': m.model,
                  'formatted_time': m.formattedTime,
                  'imageUrl': m.imageUrl,
                })
            .toList(),
      };

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.json');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat JSON Export - $userName',
      );
    } catch (e) {
      throw Exception('Failed to export as JSON: $e');
    }
  }
}
