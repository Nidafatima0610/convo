import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  ConvoCustomColors get convoColors =>
      theme.extension<ConvoCustomColors>() ??
      (isDark ? ConvoCustomColors.dark : ConvoCustomColors.light);

  bool get isDark => theme.brightness == Brightness.dark;

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;
  EdgeInsets get viewPadding => mediaQuery.padding;
}
