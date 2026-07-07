import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class AppToast {
  static void success(String message) {
    _showToast(message, AppColors.primary);
  }

  static void error(String message) {
    _showToast(message, Colors.red);
  }

  static void warning(String message) {
    _showToast(message, Colors.orange);
  }

  static void info(String message) {
    _showToast(message, Colors.blue);
  }

  static void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 5,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
