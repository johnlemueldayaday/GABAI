import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_theme.dart';
import '../pages/bai_chat.dart';

const String kBaiChatRouteName = '/bai-chat';

final BaiBubbleRouteObserver baiBubbleRouteObserver = BaiBubbleRouteObserver();
final GlobalKey<NavigatorState> baiBubbleNavigatorKey =
    GlobalKey<NavigatorState>();

class BaiBubbleRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> isBaiRouteActive = ValueNotifier(false);

  void _sync(Route<dynamic>? route) {
    isBaiRouteActive.value = route?.settings.name == kBaiChatRouteName;
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
}

class BaiFloatingBubbleHost extends StatefulWidget {
  final Widget child;

  const BaiFloatingBubbleHost({super.key, required this.child});

  @override
  State<BaiFloatingBubbleHost> createState() => _BaiFloatingBubbleHostState();
}

class _BaiFloatingBubbleHostState extends State<BaiFloatingBubbleHost> {
  bool _isHidden = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    baiBubbleRouteObserver.isBaiRouteActive.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    baiBubbleRouteObserver.isBaiRouteActive.removeListener(_handleRouteChange);
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

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx <= 0) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0, 96);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldHide =
        _dragOffset > 48 ||
        details.primaryVelocity != null && details.primaryVelocity! > 500;
    setState(() {
      _isHidden = shouldHide;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isHidden && !baiBubbleRouteObserver.isBaiRouteActive.value)
          Positioned(
            right: 18,
            bottom: 24,
            child: SafeArea(
              minimum: const EdgeInsets.only(right: 2, bottom: 2),
              child: Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: GestureDetector(
                  onTap: _openBai,
                  onHorizontalDragUpdate: _handleDragUpdate,
                  onHorizontalDragEnd: _handleDragEnd,
                  child: Container(
                    width: 58,
                    height: 58,
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
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
