import 'package:flutter/material.dart';
import 'firstPage.dart';
import 'loginPage.dart';
import 'scanPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Required for async main

  await Supabase.initialize(
    url: 'https://skvabguhagvowfrxexpx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdmFiZ3VoYWd2b3dmcnhleHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQyMDg1NDUsImV4cCI6MjA1OTc4NDU0NX0.DyqN57l6KJYbDDgBu-wHSK5Qa3XP2-V_FdTCveocrdg',
  );

  runApp(const BaymaxApp());
}

class BaymaxApp extends StatelessWidget {
  const BaymaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BayMax',
      theme: ThemeData.dark(),
      home: const LoadingPage(),
      routes: {
        '/first': (context) => const MyHomePage(title: 'Bay-Max'),
        '/login': (context) => LoginPage(),
        '/scan': (context) => const ScanPage(),
        '/todos': (context) => const HomePage(), // ✅ Supabase page route
      },
    );
  }
}
  
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pushReplacementNamed(context, '/first');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BAY-MAX',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              width: 100,
              child: Image.asset("baymax.png", fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _future = Supabase.instance.client
      .from('todos')
      .select(); // ✅ Connects to 'todos' table in Supabase

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Todos')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data!;
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: ((context, index) {
              final todo = todos[index];
              return ListTile(
                title: Text(todo['name']),
              );
            }),
          );
        },
      ),
    );
  }
}
