import 'package:flutter/material.dart';

class Password extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final IconData? icon;

  const Password({
    super.key,
    required this.hintText,
    required this.controller,
    this.icon,
  });

  @override
  _PasswordState createState() => _PasswordState();
}

class _PasswordState extends State<Password> {
  bool _obscureText = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width / 1.2,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (widget.icon != null) Icon(widget.icon, color: Colors.grey),
          SizedBox(width: widget.icon != null ? 10 : 0),
          Expanded(
            child: TextField(
              obscureText: _obscureText,
              controller: widget.controller,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.black),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: _togglePasswordVisibility,
          ),
        ],
      ),
    );
  }
}
