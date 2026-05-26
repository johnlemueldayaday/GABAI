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

  void _sync(Route<dynamic>? route) {
    isBaiRouteActive.value = route?.settings.name == kBaiChatRouteName;
    currentRouteName.value = route?.settings.name;
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
  static const double _restoreTabWidth = 44;
  static const Set<String> _excludedRouteNames = {
    kSplashRouteName,
    kCartRouteName,
    kCartDetailRouteName,
    kSettingsRouteName,
  };

  bool _isHidden = false;
  Offset? _bubblePosition;
  Offset _panStartPosition = Offset.zero;
  Offset _panDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    baiBubbleRouteObserver.isBaiRouteActive.addListener(_handleRouteChange);
    baiBubbleRouteObserver.currentRouteName.addListener(_handleRouteChange);
    SettingsService().addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    baiBubbleRouteObserver.isBaiRouteActive.removeListener(_handleRouteChange);
    baiBubbleRouteObserver.currentRouteName.removeListener(_handleRouteChange);
    SettingsService().removeListener(_handleRouteChange);
    super.dispose();
  }

  void _handleRouteChange() {
    if (mounted) setState(() {});
  }

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

  void _handlePanStart(DragStartDetails details) {
    _panStartPosition = _bubblePosition ?? Offset.zero;
    _panDelta = Offset.zero;
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

  void _handlePanEnd(DragEndDetails details) {
    final shouldHide =
        (_panDelta.dx > 92 && _panDelta.dx.abs() > _panDelta.dy.abs() * 1.4) ||
        details.velocity.pixelsPerSecond.dx > 760;

    if (!shouldHide) return;
    setState(() {
      _isHidden = true;
    });
  }

  void _restoreBubble() {
    setState(() {
      _isHidden = false;
    });
  }

  bool _isRouteExcluded(String? routeName) {
    return routeName == '/' || _excludedRouteNames.contains(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        _bubblePosition ??= _defaultPosition(constraints, padding);
        final position = _clampPosition(
          _bubblePosition!,
          constraints,
          padding,
        );
        if (position != _bubblePosition) {
          _bubblePosition = position;
        }

        final currentRoute = baiBubbleRouteObserver.currentRouteName.value;
        final excluded = _isRouteExcluded(currentRoute) ||
            baiBubbleRouteObserver.isBaiRouteActive.value ||
            !SettingsService().onboardingComplete;

        return Stack(
          children: [
            widget.child,
            if (!excluded && !_isHidden)
              Positioned(
                left: position.dx,
                top: position.dy,
                child: GestureDetector(
                  onTap: _openBai,
                  onPanStart: _handlePanStart,
                  onPanUpdate: (details) =>
                      _handlePanUpdate(details, constraints, padding),
                  onPanEnd: _handlePanEnd,
                  child: _BaiBubbleButton(),
                ),
              ),
            if (!excluded && _isHidden)
              Positioned(
                right: -6,
                top: position.dy
                    .clamp(
                      padding.top + _screenMargin,
                      constraints.maxHeight -
                          padding.bottom -
                          _restoreTabWidth -
                          _screenMargin,
                    )
                    .toDouble(),
                child: GestureDetector(
                  onTap: _restoreBubble,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -220) {
                      _restoreBubble();
                    }
                  },
                  child: const _BaiRestoreTab(),
                ),
              ),
          ],
        );
      },
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
        gradient: LinearGradient(
          colors: [kPrimary, kPrimaryLight],
        ),
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

class _BaiRestoreTab extends StatelessWidget {
  const _BaiRestoreTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _BaiFloatingBubbleHostState._restoreTabWidth,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimary, kPrimaryLight],
        ),
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 20,
          ),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'BAI',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
