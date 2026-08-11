import 'package:flutter/material.dart';

class AdminUI {
  /// Custom AppBar used across the app (settings, profile, etc.)
  static PreferredSizeWidget buildAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    Widget? bottom,
    double? bottomHeight,
  }) {
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight ?? 48.0),
              child: bottom,
            )
          : null,
    );
  }

  /// Custom Card styling matching the premium UI
  static Widget buildCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.055),
        ),
      ),
      child: child,
    );
  }
}
