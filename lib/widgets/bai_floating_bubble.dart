import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import '../navigation/app_routes.dart';
import '../pages/bai_chat.dart';
import '../services/settings_service.dart';

final BaiBubbleRouteObserver baiBubbleRouteObserver = BaiBubbleRouteObserver();
final GlobalKey<NavigatorState> baiBubbleNavigatorKey =
    GlobalKey<NavigatorState>();

class BaiBubbleRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> isBaiRouteActive = ValueNotifier(false);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);
  int _syncGeneration = 0;

  void _sync(Route<dynamic>? route) {
    final generation = ++_syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _syncGeneration) return;
      isBaiRouteActive.value = route?.settings.name == kBaiChatRouteName;
      currentRouteName.value = route?.settings.name;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _sync(previousRoute);
  }
}

class BaiFloatingBubbleHost extends StatefulWidget {
  final Widget child;

  const BaiFloatingBubbleHost({super.key, required this.child});

  @override
  State<BaiFloatingBubbleHost> createState() => _BaiFloatingBubbleHostState();
}

class _BaiFloatingBubbleHostState extends State<BaiFloatingBubbleHost> {
  static const double _bubbleSize = 58;
  static const double _screenMargin = 16;
  static const Set<String> _excludedRouteNames = {
    kSplashRouteName,
    kCartRouteName,
    kCartDetailRouteName,
    kSettingsRouteName,
  };

  bool _isHidden = false;
  bool _isDragging = false;
  Offset? _bubblePosition;
  Offset _panStartPosition = Offset.zero;
  Offset _panDelta = Offset.zero;

  void _openBai() {
    baiBubbleNavigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: kBaiChatRouteName),
        builder: (_) => const BaiChatPage(),
      ),
    );
  }

  Offset _defaultPosition(BoxConstraints constraints, EdgeInsets padding) {
    return Offset(
      constraints.maxWidth - padding.right - _bubbleSize - _screenMargin,
      constraints.maxHeight - padding.bottom - _bubbleSize - 24,
    );
  }

  Offset _clampPosition(
    Offset position,
    BoxConstraints constraints,
    EdgeInsets padding,
  ) {
    final minLeft = padding.left + _screenMargin;
    final maxLeft =
        constraints.maxWidth - padding.right - _bubbleSize - _screenMargin;
    final minTop = padding.top + _screenMargin;
    final maxTop =
        constraints.maxHeight - padding.bottom - _bubbleSize - _screenMargin;

    return Offset(
      position.dx.clamp(minLeft, maxLeft).toDouble(),
      position.dy.clamp(minTop, maxTop).toDouble(),
    );
  }

  void _handlePanStart(
    DragStartDetails details,
    BoxConstraints constraints,
    EdgeInsets padding,
  ) {
    _panStartPosition = _clampPosition(
      _bubblePosition ?? _defaultPosition(constraints, padding),
      constraints,
      padding,
    );
    _panDelta = Offset.zero;
    setState(() => _isDragging = true);
  }

  void _handlePanUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
    EdgeInsets padding,
  ) {
    _panDelta += details.delta;
    setState(() {
      _bubblePosition = _clampPosition(
        _panStartPosition + _panDelta,
        constraints,
        padding,
      );
    });
  }

  void _handlePanEnd(
    DragEndDetails details,
    BoxConstraints constraints,
    EdgeInsets padding,
  ) {
    final currentPosition = _bubblePosition ?? _panStartPosition;
    final bubbleCenter =
        currentPosition + const Offset(_bubbleSize / 2, _bubbleSize / 2);
    final dismissCenter = Offset(
      constraints.maxWidth / 2,
      constraints.maxHeight - padding.bottom - 46,
    );
    final shouldHide = (bubbleCenter - dismissCenter).distance < 78;

    setState(() {
      _isDragging = false;
      _isHidden = shouldHide;
      if (!shouldHide) {
        final snapLeft = bubbleCenter.dx < constraints.maxWidth / 2;
        _bubblePosition = Offset(
          snapLeft
              ? padding.left + _screenMargin
              : constraints.maxWidth -
                    padding.right -
                    _bubbleSize -
                    _screenMargin,
          currentPosition.dy,
        );
      }
    });
  }

  bool _isRouteExcluded(String? routeName) {
    return routeName == '/' || _excludedRouteNames.contains(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService(),
      builder: (context, _) => ValueListenableBuilder<String?>(
        valueListenable: baiBubbleRouteObserver.currentRouteName,
        builder: (context, currentRoute, _) {
          final mediaQuery = MediaQuery.of(context);
          final constraints = BoxConstraints.tight(mediaQuery.size);
          final padding = mediaQuery.padding;
          final position = _clampPosition(
            _bubblePosition ?? _defaultPosition(constraints, padding),
            constraints,
            padding,
          );
          final excluded =
              _isRouteExcluded(currentRoute) ||
              !SettingsService().onboardingComplete;

          return Stack(
            children: [
              widget.child,
              if (!excluded && _isDragging)
                Positioned(
                  left: (constraints.maxWidth - 48) / 2,
                  bottom: padding.bottom + 22,
                  child: const _DismissBubbleTarget(),
                ),
              if (!excluded && !_isHidden)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: position.dx,
                  top: position.dy,
                  child: GestureDetector(
                    onTap: _openBai,
                    onPanStart: (details) =>
                        _handlePanStart(details, constraints, padding),
                    onPanUpdate: (details) =>
                        _handlePanUpdate(details, constraints, padding),
                    onPanEnd: (details) =>
                        _handlePanEnd(details, constraints, padding),
                    child: _BaiBubbleButton(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DismissBubbleTarget extends StatelessWidget {
  const _DismissBubbleTarget();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Release to remove BAI bubble',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFB84040),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

class _BaiBubbleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _BaiFloatingBubbleHostState._bubbleSize,
      height: _BaiFloatingBubbleHostState._bubbleSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kPrimary, kPrimaryLight]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'BAI',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
