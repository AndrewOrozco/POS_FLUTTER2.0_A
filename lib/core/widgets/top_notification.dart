import 'dart:async';
import 'package:flutter/material.dart';

/// Notificación tipo Steam — aparece arriba a la derecha y se va sola.
/// Uso: TopNotification.show(context, message: '...', type: NotificationType.warning);
enum NotificationType { success, warning, error, info }

class TopNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 6),
  }) {
    // Dismiss any existing notification
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    this.subtitle,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // entra desde la derecha (como Steam)
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fondo oscuro tipo Steam — contrasta bien sobre el header rojo de Terpel
  Color get _bgColor {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF1A2E1A); // verde oscuro
      case NotificationType.warning:
        return const Color(0xFF2D2416); // ámbar oscuro
      case NotificationType.error:
        return const Color(0xFF2D1616); // rojo oscuro
      case NotificationType.info:
        return const Color(0xFF16202D); // azul oscuro
    }
  }

  /// Acento lateral de color por tipo
  Color get _accentColor {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.warning:
        return const Color(0xFFFFC107);
      case NotificationType.error:
        return const Color(0xFFEF5350);
      case NotificationType.info:
        return const Color(0xFF42A5F5);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () async {
                await _controller.reverse();
                widget.onDismiss();
              },
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: _accentColor, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: _accentColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 18),
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
