import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shop_scheme/main.dart';
import 'package:mobile_shop_scheme/retail_design.dart';
import 'widget_test.dart' show FakeAuthService;

class ReferenceAuth extends FakeAuthService {
  bool read = false;
  bool imageBanner = false;
  int bannerRequests = 0;
  int dashboardRequests = 0;
  Completer<dynamic>? pendingDashboard;
  bool failDashboard = false;
  List<Map<String, dynamic>> enrollments = [];
  final schemes = [
    {
      'id': 'mobile',
      'name': 'Mobile Upgrade',
      'monthly_amount_paise': 100000,
      'installment_count': 11,
      'benefit_paise': 100000
    },
    {
      'id': 'appliances',
      'name': 'Home Appliances',
      'monthly_amount_paise': 200000,
      'installment_count': 11,
      'benefit_paise': 200000
    },
  ];

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      Map<String, String>? headers,
      bool retry = true}) async {
    if (path == '/schemes') return schemes;
    if (path == '/dashboard') {
      dashboardRequests++;
      if (pendingDashboard != null) return pendingDashboard!.future;
      if (failDashboard) throw Exception('Could not refresh your schemes.');
      return {'enrollments': enrollments, 'unread_notifications': 0};
    }
    if (path == '/banner') bannerRequests++;
    if (path == '/banner' && imageBanner) {
      return {
        'mode': 'images',
        'slides': [
          {'image': '/uploads/banners/1.png', 'title': 'Uploaded banner one'},
          {'image': '/uploads/banners/2.png', 'title': 'Uploaded banner two'},
        ],
      };
    }
    if (path == '/notifications/n1/read') {
      read = true;
      return {'read': true};
    }
    if (path == '/notifications') {
      return [
        {
          'id': 'n1',
          'title': 'Scheme update',
          'body': 'Your installment is due.',
          'created_at': '2026-10-01T10:30:00Z',
          'read': read
        },
      ];
    }
    return super.request(path,
        method: method, body: body, headers: headers, retry: retry);
  }
}

void main() {
  Map<String, dynamic> enrolledPlan(String id, String name, int paid) => {
        'id': id,
        'status': 'ACTIVE',
        'paid_installments': paid,
        'paid_paise': paid * 100000,
        'terms': {
          'name': name,
          'installment_count': 11,
          'benefit_paise': 100000
        },
      };

  testWidgets(
      'active scheme refresh preserves banner, selection and page position',
      (tester) async {
    final auth = ReferenceAuth()..imageBanner = true;
    auth.enrollments = [
      enrolledPlan('one', 'My enrolled mobile plan', 3),
      enrolledPlan('two', 'My enrolled appliance plan', 5),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Dashboard(
                auth: auth,
                email: 'customer@example.com',
                onBrowse: () {},
                onPayments: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Mobile Upgrade'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('banner-indicator-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButton<String>));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My enrolled appliance plan').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Refresh active scheme'));
    await tester.pumpAndSettle();
    final bannerState = tester.state(find.byType(BannerCarousel));
    final cardState = tester.state(find.byType(ActiveSchemeCard));
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final offset = position.pixels;
    final pending = Completer<dynamic>();
    auth.pendingDashboard = pending;
    await tester.tap(find.byTooltip('Refresh active scheme'));
    await tester.pump();
    expect(auth.dashboardRequests, 2);
    expect(auth.bannerRequests, 1);
    expect(tester.state(find.byType(BannerCarousel)), same(bannerState));
    expect(tester.state(find.byType(ActiveSchemeCard)), same(cardState));
    expect(position.pixels, offset);
    expect(find.text('5 of 11 installments'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.byType(RetailShortcut), findsNWidgets(4));
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton &&
                widget.tooltip == 'Refresh active scheme'))
            .onPressed,
        isNull);
    pending.complete({
      'enrollments': [
        enrolledPlan('one', 'My enrolled mobile plan', 3),
        enrolledPlan('two', 'My enrolled appliance plan', 6),
      ]
    });
    await tester.pumpAndSettle();
    expect(find.text('6 of 11 installments'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(position.pixels, offset);
    expect(auth.bannerRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed card refresh retains enrolled data and retries locally',
      (tester) async {
    final auth = ReferenceAuth();
    auth.enrollments = [enrolledPlan('one', 'My enrolled plan', 3)];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Dashboard(
                auth: auth,
                email: 'customer@example.com',
                onBrowse: () {},
                onPayments: () {}))));
    await tester.pumpAndSettle();
    auth.failDashboard = true;
    await tester.tap(find.byTooltip('Refresh active scheme'));
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh your schemes.'), findsOneWidget);
    expect(find.text('My enrolled plan'), findsOneWidget);
    expect(find.text('3 of 11 installments'), findsOneWidget);
    expect(auth.bannerRequests, 1);
    auth.failDashboard = false;
    auth.enrollments = [];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('My enrolled plan'), findsNothing);
    expect(find.text('Explore schemes'), findsOneWidget);
    expect(auth.dashboardRequests, 3);
    expect(auth.bannerRequests, 1);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'catalog and inbox headings fit at width $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = ReferenceAuth();
      for (final screen in [
        SchemesPage(auth: auth),
        NotificationsPage(auth: auth)
      ]) {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: Scaffold(body: screen),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('home shows uploaded banners and one active scheme card',
      (tester) async {
    final auth = ReferenceAuth()..imageBanner = true;
    auth.enrollments = [
      {
        'id': 'active-one',
        'status': 'ACTIVE',
        'paid_installments': 3,
        'paid_paise': 300000,
        'next_due': {
          'amount_paise': 100000,
          'due_date': '2026-10-15T00:00:00Z'
        },
        'terms': {
          'name': 'My mobile plan',
          'installment_count': 11,
          'benefit_paise': 100000
        }
      },
      {
        'id': 'active-two',
        'status': 'ACTIVE',
        'paid_installments': 5,
        'paid_paise': 1000000,
        'terms': {
          'name': 'My appliance plan',
          'installment_count': 11,
          'benefit_paise': 200000
        }
      },
      {
        'id': 'completed',
        'status': 'COMPLETED',
        'terms': {'name': 'Finished plan'}
      },
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Dashboard(
      auth: auth,
      email: 'customer@example.com',
      onBrowse: () {},
      onPayments: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(SchemePromotionCard), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('banner-indicator-1')));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(auth.bannerRequests, 1);
    await tester.drag(find.byKey(const ValueKey('uploaded-banner-carousel')),
        const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(auth.bannerRequests, 1);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('banner-image-section')))
            .width,
        tester.getSize(find.byKey(const ValueKey('active-scheme-card'))).width);
    expect(find.byKey(const ValueKey('active-scheme-card')), findsOneWidget);
    expect(find.text('Finished plan'), findsNothing);
    expect(find.text('Uploaded banner one'), findsNothing);
    expect(tester.getTopLeft(find.byType(BannerCarousel)).dy,
        lessThan(tester.getTopLeft(find.byType(ActiveSchemeCard)).dy));
    expect(find.text('3 of 11 installments'), findsOneWidget);
    expect(find.text('Total saved'), findsOneWidget);
    expect(find.text('Next payment: ₹1000.00 on 2026-10-15'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My appliance plan').last);
    await tester.pumpAndSettle();
    expect(find.text('5 of 11 installments'), findsOneWidget);
    expect(find.text('Next payment: ₹1000.00 on 2026-10-15'), findsNothing);
    expect(find.byKey(const ValueKey('active-scheme-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bell opens dated inbox, marks read and returns to current tab',
      (tester) async {
    final auth = ReferenceAuth()..email = 'customer@example.com';
    await tester.pumpWidget(MaterialApp(
        home: HomePage(
      auth: auth,
      email: auth.email!,
      onSignedOut: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(
        tester.widget<Badge>(find.byType(Badge).first).isLabelVisible, isTrue);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-identity')), findsOneWidget);
    expect(find.text('Test customer'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Scheme update'), findsOneWidget);
    expect(find.text('01-Oct-2026 4:00 PM'), findsOneWidget);
    await tester.tap(find.text('Scheme update'));
    await tester.pumpAndSettle();
    expect(auth.read, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-identity')), findsOneWidget);
    expect(
        tester.widget<Badge>(find.byType(Badge).first).isLabelVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product scheme card fits narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: SchemePromotionCard(
                  scheme: ReferenceAuth().schemes.first, onTap: () {}))),
    ))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheme page uses distinct product images for different schemes',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SchemesPage(auth: ReferenceAuth()))));
    await tester.pumpAndSettle();
    final first = tester
        .widget<SchemePromotionCard>(find.byType(SchemePromotionCard).first);
    await tester.scrollUntilVisible(find.text('Home Appliances'), 200);
    final second = tester
        .widget<SchemePromotionCard>(find.byType(SchemePromotionCard).last);
    expect(first.imageAsset, isNot(second.imageAsset));
    expect(tester.takeException(), isNull);
  });
}
