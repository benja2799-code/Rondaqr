import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const RondaQRApp());
}

class RondaQRApp extends StatelessWidget {
  const RondaQRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RondaQR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}