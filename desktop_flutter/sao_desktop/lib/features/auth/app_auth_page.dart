import 'package:flutter/material.dart';

import 'app_login_page.dart';
import 'app_signup_page.dart';

class AppAuthPage extends StatefulWidget {
  const AppAuthPage({super.key});

  @override
  State<AppAuthPage> createState() => _AppAuthPageState();
}

class _AppAuthPageState extends State<AppAuthPage> {
  bool _showSignup = false;

  void _goToSignup() {
    setState(() => _showSignup = true);
  }

  void _goToLogin() {
    setState(() => _showSignup = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSignup) {
      return AppSignupPage(onBackToLogin: _goToLogin);
    } else {
      return AppLoginPage(onGoToSignup: _goToSignup);
    }
  }
}

