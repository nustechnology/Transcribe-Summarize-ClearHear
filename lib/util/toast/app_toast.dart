import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class AppToast {
  static OverlayEntry? _activeBanner;

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

  static void sessionSaved({
    required String title,
    String? subtitle,
  }) {
    final cleanedSubtitle =
        subtitle?.replaceFirst(RegExp(r'^\s*-\s*'), '').trim();

    _showBannerToast(
      icon: Icons.check_rounded,
      iconColor: AppColors.primary,
      iconBackgroundColor: const Color(0xFFE3F0F0),
      title: title,
      subtitle: cleanedSubtitle?.isNotEmpty == true ? cleanedSubtitle : null,
    );
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

  static void _showBannerToast({
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    void show() {
      final overlay = _resolveOverlay();
      if (overlay == null) {
        success(subtitle == null ? title : '$title\n$subtitle');
        return;
      }

      _dismissActiveBanner();

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _AppToastBanner(
          icon: icon,
          iconColor: iconColor,
          iconBackgroundColor: iconBackgroundColor,
          title: title,
          subtitle: subtitle,
          duration: duration,
          onDismissed: () {
            entry.remove();
            if (_activeBanner == entry) {
              _activeBanner = null;
            }
          },
        ),
      );

      _activeBanner = entry;
      overlay.insert(entry);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }

  static OverlayState? _resolveOverlay() {
    final navigatorOverlay = Get.key.currentState?.overlay;
    if (navigatorOverlay != null) {
      return navigatorOverlay;
    }

    for (final context in [Get.overlayContext, Get.context]) {
      if (context == null) continue;
      try {
        return Overlay.of(context, rootOverlay: true);
      } catch (_) {}
    }

    return null;
  }

  static void _dismissActiveBanner() {
    _activeBanner?.remove();
    _activeBanner = null;
  }
}

class _AppToastBanner extends StatefulWidget {
  const _AppToastBanner({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.duration,
    required this.onDismissed,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToastBanner> createState() => _AppToastBannerState();
}

class _AppToastBannerState extends State<_AppToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  var _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + 12,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.iconBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
