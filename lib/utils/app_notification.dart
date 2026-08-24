import 'dart:async';
import 'package:flutter/material.dart';
import '../services/theme_provider.dart';
import '../theme/theme.dart';

class AppNotification {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
    Duration displayDuration = const Duration(seconds: 2),
  }) {
    // Remove active notification if present
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _BouncingToastWidget(
          message: message,
          isError: isError,
          icon: icon,
          displayDuration: displayDuration,
          onDismissed: () {
            if (_currentEntry == entry) {
              entry.remove();
              _currentEntry = null;
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _BouncingToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final Duration displayDuration;
  final VoidCallback onDismissed;

  const _BouncingToastWidget({
    required this.message,
    required this.isError,
    this.icon,
    required this.displayDuration,
    required this.onDismissed,
  });

  @override
  State<_BouncingToastWidget> createState() => _BouncingToastWidgetState();
}

class _BouncingToastWidgetState extends State<_BouncingToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 300),
    );

    // Bounce-In Curve (elastic & back out) & Bounce-Out Curve (back in)
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );

    // Trigger bounce in
    _controller.forward();

    // Schedule bounce out
    _timer = Timer(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryAccent = ThemeProvider.greenAccentColor;
    const bg = Color(0xFF242528);
    const textColor = Colors.white;
    final borderColor = widget.isError
        ? AppTheme.errorColor
        : primaryAccent;

    return Positioned(
      top: 0,
      bottom: 82,
      left: 20,
      right: 20,
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.isError
                              ? AppTheme.errorColor.withValues(alpha: 0.2)
                              : primaryAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon ??
                              (widget.isError
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded),
                          color: widget.isError
                              ? AppTheme.errorColor
                              : primaryAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontFamily: 'Utendo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
