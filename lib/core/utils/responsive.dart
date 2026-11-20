import 'package:flutter/widgets.dart';

/// Three layouts used across the whole app.
enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeForWidth(double width) {
  if (width < 600) return ScreenSize.compact;
  if (width < 1024) return ScreenSize.medium;
  return ScreenSize.expanded;
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => screenSizeForWidth(MediaQuery.sizeOf(this).width);
  bool get isCompact => screenSize == ScreenSize.compact;
}
