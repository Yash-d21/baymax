import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _hasSubmitted = false;
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = false;
  bool _isConnected = false;
  String _connectionError = '';
  String _currentModel = '';

  // API key
  final String apiKey = 'AIzaSyBKJqwrEsVNpkAYBQkef_yxEUaDD4kc5gU'; // Replace if invalid: https://aistudio.google.com/

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
    // Initialize with sample quizzes for testing
    _quizzes = [
      {
        'question': 'What is the main purpose of OCR technology?',
        'options': [
          'To compress images',
          'To convert text in images to machine-readable text',
          'To enhance image quality',
          'To encrypt documents'
        ],
        'correctAnswer': 'To convert text in images to machine-readable text'
      },
      {
        'question': 'Which file format is most commonly used for document sharing?',
        'options': ['JPG', 'TXT', 'PDF', 'DOC'],
        'correctAnswer': 'PDF'
      },
      {
        'question': 'What does PDF stand for?',
        'options': [
          'Personal Document Format',
          'Portable Document Format',
          'Protected Document File',
          'Public Domain File'
        ],
        'correctAnswer': 'Portable Document Format'
      },
    ];
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
        model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
        );
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
                    final url = Uri.parse('https://console.cloud.google.com/billing');
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

  // Generate quizzes from PDF
  Future<void> _generateQuizzesFromPdf() async {
    if (!_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not connected to API. Retry connection.")),
        );
      }
      return;
    }

    setState(() => _loading = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      try {
        late Uint8List pdfBytes;
        if (kIsWeb) {
          pdfBytes = result.files.single.bytes!;
        } else {
          final file = File(result.files.single.path!);
          pdfBytes = await file.readAsBytes();
        }

        // Extract text from PDF
        final document = PdfDocument(inputBytes: pdfBytes);
        final extractor = PdfTextExtractor(document);
        final extractedText = extractor.extractText();

        if (extractedText.trim().isEmpty) {
          throw Exception("No readable text found in PDF. Ensure it's not image-based.");
        }

        // Truncate text for Gemini
        final truncatedText = extractedText.length > 4000
            ? extractedText.substring(0, 4000)
            : extractedText;

        // Prompt for quiz generation
        final prompt = '''
You are an expert in creating educational quizzes. From the following content, generate exactly 5 quiz questions in strict multiple-choice format. Each question must have a clear question, four options (A, B, C, D), and the correct answer. Do not include introductions, explanations, or extra text. Use this exact format for each quiz question:
Q: [Question]
A: [Option A]
B: [Option B]
C: [Option C]
D: [Option D]
Correct: [Correct Option Letter]

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
          throw Exception("Gemini returned no content. Try a different PDF or check quota.");
        }

        // Parse quizzes
        final List<Map<String, dynamic>> quizzes = [];
        final pattern = RegExp(
          r'Q:\s*(.+?)\nA:\s*(.+?)\nB:\s*(.+?)\nC:\s*(.+?)\nD:\s*(.+?)\nCorrect:\s*([A-D])(?=\nQ:|\n?$)',
          dotAll: true,
        );
        final matches = pattern.allMatches(output);

        for (final match in matches) {
          final question = match.group(1)?.trim();
          final optionA = match.group(2)?.trim();
          final optionB = match.group(3)?.trim();
          final optionC = match.group(4)?.trim();
          final optionD = match.group(5)?.trim();
          final correct = match.group(6)?.trim();
          if (question != null &&
              optionA != null &&
              optionB != null &&
              optionC != null &&
              optionD != null &&
              correct != null &&
              question.isNotEmpty &&
              optionA.isNotEmpty &&
              optionB.isNotEmpty &&
              optionC.isNotEmpty &&
              optionD.isNotEmpty &&
              correct.isNotEmpty) {
            final correctAnswer = [optionA, optionB, optionC, optionD][['A', 'B', 'C', 'D'].indexOf(correct)];
            quizzes.add({
              'question': question,
              'options': [optionA, optionB, optionC, optionD],
              'correctAnswer': correctAnswer,
            });
          }
        }

        if (quizzes.isEmpty) {
          throw Exception("No valid quizzes parsed. Gemini output may not match expected format.");
        }

        setState(() {
          _quizzes = quizzes;
          _currentQuestionIndex = 0;
          _selectedAnswer = null;
          _hasSubmitted = false;
        });
      } catch (e) {
        if (mounted) {
          String errorMessage;
          if (e.toString().contains("401")) {
            errorMessage = "Authentication error: Check API key.";
          } else if (e.toString().contains("429")) {
            errorMessage = "Quota exceeded: Set up billing or try again later.";
          } else if (e.toString().contains("timeout")) {
            errorMessage = "Request timed out: Check your connection.";
          } else if (e.toString().contains("No readable text")) {
            errorMessage = "PDF contains no readable text. Use a text-based PDF.";
          } else if (e.toString().contains("No valid quizzes")) {
            errorMessage = "Failed to generate quizzes. Try a different PDF.";
          } else {
            errorMessage = "Error generating quizzes: $e";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              action: errorMessage.contains("Quota exceeded")
                  ? SnackBarAction(
                      label: 'Set up Billing',
                      onPressed: () async {
                        final url = Uri.parse('https://console.cloud.google.com/billing');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                    )
                  : null,
            ),
          );
        }
      } finally {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No PDF selected.")),
        );
      }
    }
  }

  void _checkAnswer() {
    setState(() {
      _hasSubmitted = true;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _quizzes.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _hasSubmitted = false;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswer = null;
        _hasSubmitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _testModels,
            tooltip: 'Retry Connection',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _loading || !_isConnected ? null : _generateQuizzesFromPdf,
            tooltip: 'Upload PDF',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quizzes.isEmpty
              ? Center(
                  child: Text(
                    _isConnected
                        ? 'No quizzes yet. Upload a PDF!'
                        : 'Please connect to a valid model first.',
                    style: const TextStyle(fontSize: 18),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${_quizzes.length}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _quizzes[_currentQuestionIndex]['question'],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _quizzes[_currentQuestionIndex]['options'].length,
                          itemBuilder: (context, index) {
                            final option = _quizzes[_currentQuestionIndex]['options'][index];
                            final isSelected = _selectedAnswer == option;
                            final isCorrectOption =
                                option == _quizzes[_currentQuestionIndex]['correctAnswer'];
                            Color? optionColor;
                            if (_hasSubmitted) {
                              if (isCorrectOption) {
                                optionColor = Colors.green.shade700;
                              } else if (isSelected && !isCorrectOption) {
                                optionColor = Colors.red.shade700;
                              }
                            } else if (isSelected) {
                              optionColor = Colors.blue.shade700;
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Material(
                                color: optionColor,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: _hasSubmitted
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedAnswer = option;
                                          });
                                        },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.grey.shade600,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${String.fromCharCode(65 + index)}.',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                        if (_hasSubmitted && isCorrectOption)
                                          const Icon(Icons.check_circle, color: Colors.white),
                                        if (_hasSubmitted && isSelected && !isCorrectOption)
                                          const Icon(Icons.cancel, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                              child: const Text('Previous'),
                            ),
                            ElevatedButton(
                              onPressed: _hasSubmitted 
                                ? (_currentQuestionIndex < _quizzes.length - 1 ? _nextQuestion : null)
                                : (_selectedAnswer != null ? _checkAnswer : null),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasSubmitted ? Colors.blue : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_hasSubmitted ? 'Next' : 'Submit'),
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