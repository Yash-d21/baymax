import 'package:flutter/material.dart';

class OptionsPage extends StatelessWidget {
  final String summarizedText;

  const OptionsPage({super.key, required this.summarizedText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Study Tools',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flash_on, color: Colors.amber),
              title: const Text('Flashcards'),
              subtitle: const Text('Create and study with flashcards'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/flashcards'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz, color: Colors.green),
              title: const Text('Quiz'),
              subtitle: const Text('Test your knowledge with quizzes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/quiz'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat, color: Colors.blue),
              title: const Text('Chatbot'),
              subtitle: const Text('Ask questions about the material'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/chatbot'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description, color: Colors.purple),
              title: const Text('Summary'),
              subtitle: const Text('View and download summary'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/summary'),
            ),
          ),
        ],
      ),
    );
  }
}