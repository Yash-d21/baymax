import 'package:baymax/firstPage.dart';
import 'package:baymax/loginPage.dart';
import 'package:baymax/textFields/pswd.dart';
import 'package:baymax/textFields/textField.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  // Get a reference to Supabase client
  final supabase = Supabase.instance.client;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        throw Exception('Please fill in all fields');
      }

      // Sign up with Supabase
      final AuthResponse res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'username': usernameController.text.trim(),
        },
      );

      // Check if sign up was successful
      if (res.user != null) {
        // Show success message and navigate to login page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please check your email to verify your account.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 43, 43, 43),
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            children: [
              SizedBox(width: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                height: 50,
                width: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyHomePage(title: 'Bay-Max'),
                      ),
                    );
                  },
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.all(15)),
                    backgroundColor: WidgetStateProperty.all(
                      Color.fromARGB(255, 54, 53, 53),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),
                  ),
                  child: Icon(Icons.arrow_back),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height / 7),
          Row(
            children: [
              SizedBox(width: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height / 5,
                width: MediaQuery.of(context).size.width / 2,
                child: Text(
                  'Create your\n Account',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20),
                  Column(
                    children: [
                      CustomTextField(
                        hintText: "Enter Username",
                        controller: usernameController,
                        icon: Icons.person,
                      ),
                
                      SizedBox(height: 20),
                      CustomTextField(
                        hintText: "Enter Email ID",
                        controller: emailController,
                        icon: Icons.mail,
                      ),
                
                      SizedBox(height: 20),
                      Password(
                        hintText: "Password",
                        controller: passwordController,
                        icon: Icons.lock,
                      ),
                
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            child: Text(
                              'Already have an account?',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ).copyWith(
                              overlayColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                              splashFactory: NoSplash.splashFactory,
                            ),
                            child: Text(
                              'Click Here',
                              style: TextStyle(
                                color: Colors.red,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 54, 53, 53),
                          minimumSize: Size(
                            MediaQuery.of(context).size.width / 1.2,
                            50,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading 
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Register',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}