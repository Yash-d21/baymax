import 'package:baymax/firstPage.dart';
import 'package:baymax/preferences.dart';
import 'package:baymax/security.dart';
import 'package:baymax/support.dart';
import 'package:flutter/material.dart';
import 'ScanPage.dart';
// renamed to scanpage.dart or baymax.dart if needed


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ScanPage()),
      );
    }
  }

  Widget _buildProfileButton(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool showArrow = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size(
            MediaQuery.of(context).size.width / 1.2,
            MediaQuery.of(context).size.height / 12,
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            if (showArrow)
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 43, 43, 43),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 43, 43, 43),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20),
              CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey,
                child: const Icon(Icons.person, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'User Name',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('mailid123@gmail.com', style: TextStyle(color: Colors.grey)),
              SizedBox(height: MediaQuery.of(context).size.height / 12),

              // Profile Buttons with respective navigation
              _buildProfileButton(Icons.settings, 'Preferences', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Preferences()),
                );
              }),
              SizedBox(height: 20),
              _buildProfileButton(Icons.security, 'Account Security', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Security()),
                );
              }),
              SizedBox(height: 20),
              _buildProfileButton(Icons.headset_mic, 'Customer Support', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Support()),
                );
              }),
              SizedBox(height: 20),
              _buildProfileButton(Icons.logout, 'Logout', () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyHomePage(title: 'Bay-Max'),
                  ),
                );
              }, showArrow: false),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Search clicked!")));
        },
        child: const Icon(Icons.search, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 50),
              onPressed: () => _onItemTapped(0),
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
                size: 50,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
