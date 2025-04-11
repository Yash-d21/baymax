import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as gen_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  String _summary = '';
  String _documentTitle = 'Document Summary';
  bool _loading = false;
  bool _isConnected = false;
  String _connectionError = '';
  String _currentModel = '';

  final String apiKey = 'AIzaSyBKJqwrEsVNpkAYBQkef_yxEUaDD4kc5gU'; // Your Gemini API Key
  late GenerativeModel model;

  final List<String> _modelNames = [
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-1.0-pro',
    'gemini-pro',
  ];

  @override
  void initState() {
    super.initState();
    _testModels();
  }

  Future<void> _testModels() async {
    setState(() {
      _loading = true;
      _connectionError = '';
      _isConnected = false;
      _currentModel = '';
    });

    for (final modelName in _modelNames) {
      try {
        model = GenerativeModel(model: modelName, apiKey: apiKey);
        final content = [Content.text("Test model")];
        final response = await model.generateContent(content).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Timeout"),
        );
        if ((response.text ?? '').isNotEmpty) {
          setState(() {
            _isConnected = true;
            _currentModel = modelName;
          });
          break;
        }
      } catch (e) {
        setState(() => _connectionError = "Connection error: $e");
      }
    }

    if (!_isConnected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_connectionError)),
      );
    }

    setState(() => _loading = false);
  }

  Future<T> _retry<T>(Future<T> Function() fn, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await fn();
      } catch (_) {
        if (i == retries - 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw Exception("Retry failed");
  }

  Future<void> _generateSummaryFromPdf() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("API not connected. Try again.")),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No file selected.")),
      );
      return;
    }

    try {
      Uint8List pdfBytes;
      if (kIsWeb) {
        pdfBytes = result.files.single.bytes!;
      } else {
        final file = File(result.files.single.path!);
        pdfBytes = await file.readAsBytes();
      }

      _documentTitle = '${result.files.single.name.replaceAll('.pdf', '')} Summary';

      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();

      if (text.trim().isEmpty) {
        throw Exception("PDF has no readable text.");
      }

      final truncated = text.length > 10000 ? text.substring(0, 10000) : text;

      final prompt = '''
Create a detailed summary of the document below:
- Cover all major points.
- Be 500-800 words.
- Use professional language.

Document:
$truncated
''';

      final response = await _retry(() => model.generateContent([Content.text(prompt)]));
      final output = response.text ?? '';

      if (output.trim().isEmpty) throw Exception("Empty response from API");

      setState(() => _summary = output);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadSummary(BuildContext context) async {
    if (_summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No summary to download.")),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _documentTitle,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Generated using $_currentModel',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: gen_pdf.PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(_summary, style: const pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = '${_documentTitle.replaceAll(' ', '_')}.pdf';

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF download not supported on web.")),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: _documentTitle,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Downloaded successfully.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download error: $e")),
      );
    }
  }

  Widget summarizedText({required String summarizedText}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        summarizedText,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Summary Generator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_summary.isNotEmpty) {
                Navigator.pop(context, _summary); // Pass summary back
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No summary generated.")),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Pick PDF and Generate Summary"),
                    onPressed: _generateSummaryFromPdf,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _summary.isEmpty
                        ? const Center(child: Text("No summary generated yet."))
                        : SingleChildScrollView(
                            child: summarizedText(summarizedText: _summary),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _downloadSummary(context),
        icon: const Icon(Icons.download),
        label: const Text("Download PDF"),
      ),
    );
  }
}
