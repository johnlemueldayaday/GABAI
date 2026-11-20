import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/navigation/app_routes.dart';
import 'package:gabay/navigation/gab_deep_link_observer.dart';
import 'package:gabay/pages/gab_chat.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
  });

  testWidgets('GAB link waits for dashboard, then opens chat', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = GabDeepLinkObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        initialRoute: kSplashRouteName,
        navigatorObservers: [observer],
        routes: {
          kSplashRouteName: (_) => const Scaffold(body: Text('Splash')),
          kDashboardRouteName: (_) => const Scaffold(body: Text('Dashboard')),
        },
      ),
    );

    observer.handleUri(Uri.parse('gabay://gab-chat'));
    await tester.pump();
    expect(find.byType(GabChatPage), findsNothing);

    navigatorKey.currentState!.pushReplacementNamed(kDashboardRouteName);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GabChatPage), findsOneWidget);
  });

  testWidgets('unrelated app links do not open GAB chat', (tester) async {
    final observer = GabDeepLinkObserver();
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: kDashboardRouteName,
        navigatorObservers: [observer],
        routes: {
          kDashboardRouteName: (_) => const Scaffold(body: Text('Dashboard')),
        },
      ),
    );

    observer.handleUri(Uri.parse('gabay://wallet'));
    await tester.pump();

    expect(find.byType(GabChatPage), findsNothing);
  });
}
