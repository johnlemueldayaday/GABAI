import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../pages/gab_chat.dart';
import 'app_routes.dart';

bool isGabChatDeepLink(Uri uri) {
  return uri.scheme == 'gabay' &&
      uri.host == 'gab-chat' &&
      (uri.path.isEmpty || uri.path == '/');
}

class GabDeepLinkObserver extends NavigatorObserver {
  GabDeepLinkObserver({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  final List<Route<dynamic>> _routes = [];
  StreamSubscription<Uri>? _subscription;
  bool _pendingGabChat = false;
  bool _pushScheduled = false;

  void start() {
    _subscription = _appLinks.uriLinkStream.listen(
      handleUri,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'GAB deep links',
            context: ErrorDescription('while listening for app links'),
          ),
        );
      },
    );
    unawaited(_readInitialLink());
  }

  Future<void> _readInitialLink() async {
    try {
      handleUri(await _appLinks.getInitialLink());
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'GAB deep links',
          context: ErrorDescription('while reading the initial app link'),
        ),
      );
    }
  }

  void dispose() {
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _subscription = null;
  }

  void handleUri(Uri? uri) {
    if (uri == null || !isGabChatDeepLink(uri)) return;
    _pendingGabChat = true;
    _openGabChatWhenReady();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _routes.add(route);
    super.didPush(route, previousRoute);
    _openGabChatWhenReady();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didPop(route, previousRoute);
    _openGabChatWhenReady();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didRemove(route, previousRoute);
    _openGabChatWhenReady();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final oldIndex = _routes.indexOf(oldRoute);
      if (oldIndex >= 0) {
        if (newRoute == null) {
          _routes.removeAt(oldIndex);
        } else {
          _routes[oldIndex] = newRoute;
        }
      } else if (newRoute != null) {
        _routes.add(newRoute);
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _openGabChatWhenReady();
  }

  void _openGabChatWhenReady() {
    if (!_pendingGabChat || _pushScheduled || navigator == null) return;
    if (!_routes.any((route) => route.settings.name == kDashboardRouteName)) {
      return;
    }

    final chatIndex = _routes.lastIndexWhere(
      (route) => route.settings.name == kGabChatRouteName,
    );
    if (chatIndex >= 0) {
      _pendingGabChat = false;
      if (chatIndex != _routes.length - 1) {
        navigator!.popUntil(
          (route) => route.settings.name == kGabChatRouteName,
        );
      }
      return;
    }

    _pendingGabChat = false;
    _pushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = navigator;
      if (currentNavigator == null || !currentNavigator.mounted) {
        _pendingGabChat = true;
        _pushScheduled = false;
        return;
      }
      currentNavigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: kGabChatRouteName),
          builder: (_) => const GabChatPage(),
        ),
      );
      _pushScheduled = false;
    });
  }
}
