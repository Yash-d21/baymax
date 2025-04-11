import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';

class FlashcardPage extends StatefulWidget {
  const FlashcardPage({super.key});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _loading = false;
  bool _isConnected = false;
  String _connectionError = '';
  String _currentModel = '';

  List<Map<String, String>> _flashcards = [];

  // API key (replace with your own)
  final String apiKey = 'AIzaSyBDy_jnlq2VvUWmAJHSWHSUmeXYV7Ohoz0'; // e.g., 'AIzaSyBKJqwrEsVNpkAYBQkef_yxEUaDD4kc5gU'

  late GenerativeModel model;

  // Models to test
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

  // Test models for validity
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
        final content = [Content.text("Test model validity")];
        final response = await model.generateContent(content).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("API timed out for $modelName"),
        );
        final text = response.text ?? '';
        if (text.isNotEmpty) {
          setState(() {
            _isConnected = true;
            _currentModel = modelName;
            _connectionError = '';
          });
          break;
        } else {
          throw Exception("Empty response from $modelName");
        }
      } catch (e) {
        String errorMessage;
        if (e.toString().contains("401")) {
          errorMessage = "Invalid API key. Replace it in Google Cloud Console.";
          setState(() => _connectionError = errorMessage);
          break;
        } else if (e.toString().contains("429")) {
          errorMessage = "Quota exceeded. Set up billing or wait for reset.";
          setState(() => _connectionError = errorMessage);
        } else if (e.toString().contains("404")) {
          errorMessage = "Model $modelName not found.";
          setState(() => _connectionError = errorMessage);
        } else {
          errorMessage = "Failed to connect with $modelName: $e";
          setState(() => _connectionError = errorMessage);
        }
      }
    }

    if (!_isConnected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_connectionError.isEmpty
              ? "No valid models found. Check API key or model names."
              : _connectionError),
          action: _connectionError.contains("Quota exceeded")
              ? SnackBarAction(
                  label: 'Set up Billing',
                  onPressed: () async {
                    final url =
                        Uri.parse('https://console.cloud.google.com/billing');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                )
              : null,
        ),
      );
    }

    setState(() => _loading = false);
  }

  // Retry logic
  Future<T> _retry<T>(Future<T> Function() fn, {int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await fn();
      } catch (e) {
        if (i == retries - 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw Exception("Retry failed");
  }

  // Generate flashcards from PDF
  Future<void> _generateFlashcardsFromPdf() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected to API. Retry connection.")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _currentIndex = 0;
      _showAnswer = false;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final pdfBytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: pdfBytes);
        final extractor = PdfTextExtractor(document);
        final extractedText = extractor.extractText();

        if (extractedText.trim().isEmpty) {
          throw Exception(
              "No readable text found in PDF. Ensure it’s not image-based.");
        }

        final truncatedText = extractedText.length > 4000
            ? extractedText.substring(0, 4000)
            : extractedText;

        final prompt = '''
You are an expert in creating educational flashcards for advanced learners. From the provided content, generate exactly 5 flashcards in strict Q&A format. Each question should be insightful, specific, and designed to test deep understanding of the material. Answers should be concise, accurate, and directly address the question. Avoid overly simple or generic questions. Use this exact format for each flashcard:
Q: [Question]
A: [Answer]

Content:
$truncatedText
''';

        final content = [Content.text(prompt)];
        final response = await _retry(() => model.generateContent(content).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception("Gemini API timed out"),
            ));
        final output = response.text ?? '';

        if (output.trim().isEmpty) {
          throw Exception(
              "Gemini returned no content. Try a different PDF or check quota.");
        }

        final List<Map<String, String>> cards = [];
        final pattern =
            RegExp(r'Q:\s*(.+?)\nA:\s*(.+?)(?=\nQ:|\n?$)', dotAll: true);
        final matches = pattern.allMatches(output);

        for (final match in matches) {
          final question = match.group(1)?.trim();
          final answer = match.group(2)?.trim();
          if (question != null &&
              answer != null &&
              question.isNotEmpty &&
              answer.isNotEmpty) {
            cards.add({
              'question': question,
              'answer': answer,
            });
          }
        }

        if (cards.isEmpty) {
          throw Exception(
              "No valid flashcards parsed. Gemini output may not match expected format.");
        }

        setState(() {
          _flashcards = cards;
          _currentIndex = 0;
        });
      } catch (e) {
        String errorMessage;
        if (e.toString().contains("401")) {
          errorMessage = "Authentication error: Check API key.";
        } else if (e.toString().contains("429")) {
          errorMessage = "Quota exceeded: Set up billing or try again later.";
        } else if (e.toString().contains("timeout")) {
          errorMessage = "Request timed out: Check your connection.";
        } else if (e.toString().contains("No readable text")) {
          errorMessage = "PDF contains no readable text. Use a text-based PDF.";
        } else if (e.toString().contains("No valid flashcards")) {
          errorMessage = "Failed to generate flashcards. Try a different PDF.";
        } else {
          errorMessage = "Error generating flashcards: $e";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            action: errorMessage.contains("Quota exceeded")
                ? SnackBarAction(
                    label: 'Set up Billing',
                    onPressed: () async {
                      final url = Uri.parse(
                          'https://console.cloud.google.com/billing');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  )
                : null,
          ),
        );
      } finally {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No PDF selected.")),
      );
    }
  }

  void _nextCard() {
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex + 1) % _flashcards.length;
    });
  }

  void _previousCard() {
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex - 1 + _flashcards.length) % _flashcards.length;
    });
  }

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _testModels,
            tooltip: 'Retry Connection',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _loading || !_isConnected ? null : _generateFlashcardsFromPdf,
            tooltip: 'Upload PDF',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Connection status
                  Text(
                    _isConnected
                        ? 'Connected to model: $_currentModel'
                        : _connectionError.isEmpty
                            ? 'Checking model validity...'
                            : _connectionError,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Card counter
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _flashcards.isEmpty
                          ? 'No flashcards available'
                          : 'Card ${_currentIndex + 1} of ${_flashcards.length}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Flashcard display
                  Expanded(
                    child: _flashcards.isEmpty
                        ? Center(
                            child: Text(
                              _isConnected
                                  ? 'No flashcards yet. Upload a PDF!'
                                  : 'Please connect to a valid model first.',
                              style: const TextStyle(fontSize: 18),
                            ),
                          )
                        : GestureDetector(
                            onTap: _toggleAnswer,
                            child: Card(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _showAnswer
                                        ? [
                                            Colors.blue.shade800,
                                            Colors.blue.shade500
                                          ]
                                        : [
                                            Colors.purple.shade800,
                                            Colors.purple.shade500
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _showAnswer ? 'Answer:' : 'Question:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _showAnswer
                                            ? _flashcards[_currentIndex]
                                                ['answer']!
                                            : _flashcards[_currentIndex]
                                                ['question']!,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 30),
                                      const Text(
                                        'Tap to flip card',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 30),
                          onPressed: _flashcards.isEmpty ? null : _previousCard,
                        ),
                        ElevatedButton(
                          onPressed: _flashcards.isEmpty ? null : _toggleAnswer,
                          child:
                              Text(_showAnswer ? 'Show Question' : 'Show Answer'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 30),
                          onPressed: _flashcards.isEmpty ? null : _nextCard,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}