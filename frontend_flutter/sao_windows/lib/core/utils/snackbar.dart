import 'package:flutter/material.dart';

const Duration _kDefaultSnackBarDuration = Duration(seconds: 4);

SnackBar appSnackBar({
  required String message,
  Color? backgroundColor,
  SnackBarAction? action,
  Duration duration = _kDefaultSnackBarDuration,
  SnackBarBehavior behavior = SnackBarBehavior.floating,
}) {
  return SnackBar(
    content: Text(message),
    backgroundColor: backgroundColor,
    action: action,
    duration: duration,
    behavior: behavior,
  );
}

void showTransientSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}
