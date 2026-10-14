import 'dart:async';

import 'package:firebase_remote_update/firebase_remote_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable [AppUpdateService] stand-in.
///
/// [evaluate] waits for [completer] to complete before returning [decision],
/// so tests can simulate slow or fast evaluations.
class _FakeUpdateService implements AppUpdateService {
  _FakeUpdateService(this.decision, this.completer);

  final UpdateDecision decision;
  final Completer<void> completer;

  @override
  AppUpdateConfig get config =>
      const AppUpdateConfig(androidPackageId: '', iosAppStoreId: '');

  @override
  Future<UpdateDecision> evaluate() async {
    evaluations++;
    await completer.future;
    return decision;
  }

  @override
  Future<void> startUpdate() async {}

  final updates = StreamController<void>.broadcast();
  var evaluations = 0;

  @override
  Stream<void> configUpdates() => updates.stream;
}

const _childKey = Key('child');
const _forcedKey = Key('forced');
const _loadingKey = Key('loading');

Widget _child() => const Scaffold(body: Text('app', key: _childKey));

Widget _forcedBuilder(BuildContext _, UpdateDecision d) =>
    const Scaffold(body: Text('forced', key: _forcedKey));

Widget _loadingBuilder(BuildContext _) =>
    const Scaffold(body: Text('loading', key: _loadingKey));

/// Wraps [widget] in a [MaterialApp] so that [Scaffold] has the required
/// [Directionality] ancestor.
Widget _wrap(Widget widget) => MaterialApp(home: widget);

void main() {
  group('UpdateGate — nonBlocking mode (default)', () {
    testWidgets('shows child immediately before evaluation completes', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      // Only one frame — evaluation hasn't completed yet.
      expect(find.byKey(_childKey), findsOneWidget);
      expect(find.byKey(_forcedKey), findsNothing);
    });

    testWidgets('swaps to forced screen when evaluation returns forced', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision(
          requirement: UpdateRequirement.forced,
          message: 'Update now',
        ),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      // Before evaluation: child is visible.
      expect(find.byKey(_childKey), findsOneWidget);

      // Complete evaluation and pump.
      completer.complete();
      await tester.pumpAndSettle();

      // After evaluation: forced screen is visible.
      expect(find.byKey(_forcedKey), findsOneWidget);
      expect(find.byKey(_childKey), findsNothing);
    });

    testWidgets('stays on child when evaluation returns none', (tester) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_childKey), findsOneWidget);
      expect(find.byKey(_forcedKey), findsNothing);
    });

    testWidgets('stays on child when evaluation returns optional', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision(requirement: UpdateRequirement.optional),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_childKey), findsOneWidget);
      expect(find.byKey(_forcedKey), findsNothing);
    });
  });

  group('UpdateGate — blocking mode', () {
    testWidgets('shows loadingBuilder before evaluation completes', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            mode: UpdateGateMode.blocking,
            loadingBuilder: _loadingBuilder,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      expect(find.byKey(_loadingKey), findsOneWidget);
      expect(find.byKey(_childKey), findsNothing);
    });

    testWidgets('shows default spinner when no loadingBuilder is provided', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            mode: UpdateGateMode.blocking,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(_childKey), findsNothing);
    });

    testWidgets('shows forced screen when evaluation returns forced', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision(
          requirement: UpdateRequirement.forced,
          message: 'Update now',
        ),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            mode: UpdateGateMode.blocking,
            loadingBuilder: _loadingBuilder,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_forcedKey), findsOneWidget);
      expect(find.byKey(_childKey), findsNothing);
    });

    testWidgets('shows child when evaluation returns none', (tester) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            mode: UpdateGateMode.blocking,
            loadingBuilder: _loadingBuilder,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_childKey), findsOneWidget);
      expect(find.byKey(_loadingKey), findsNothing);
    });
  });

  group('UpdateGate — onDecision callback', () {
    testWidgets('calls onDecision with the resolved decision', (tester) async {
      final completer = Completer<void>();
      const expected = UpdateDecision(
        requirement: UpdateRequirement.optional,
        message: 'New version available',
      );
      final service = _FakeUpdateService(expected, completer);

      UpdateDecision? captured;
      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            onDecision: (d) => captured = d,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      completer.complete();
      await tester.pumpAndSettle();

      expect(captured, expected);
    });

    testWidgets('does not call onDecision if unmounted before completion', (
      tester,
    ) async {
      final completer = Completer<void>();
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        completer,
      );

      var called = false;
      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            onDecision: (_) => called = true,
            forcedBuilder: _forcedBuilder,
            child: _child(),
          ),
        ),
      );

      // Unmount before evaluation completes.
      await tester.pumpWidget(_wrap(const SizedBox()));

      completer.complete();
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });
  });

  group('UpdateGate — re-checks', () {
    Future<_FakeUpdateService> pumpGate(
      WidgetTester tester, {
      Duration? recheckInterval,
      bool listen = false,
    }) async {
      final service = _FakeUpdateService(
        const UpdateDecision.none(),
        Completer<void>()..complete(),
      );
      await tester.pumpWidget(
        _wrap(
          UpdateGate(
            service: service,
            forcedBuilder: _forcedBuilder,
            recheckInterval: recheckInterval,
            listenForRealtimeUpdates: listen,
            child: _child(),
          ),
        ),
      );
      await tester.pump();
      return service;
    }

    testWidgets('a published config update re-checks at once', (tester) async {
      final service = await pumpGate(tester, listen: true);
      expect(service.evaluations, 1);

      service.updates.add(null);
      await tester.pump();

      expect(service.evaluations, 2);
    });

    testWidgets('config updates are ignored unless listening', (tester) async {
      final service = await pumpGate(tester);
      expect(service.updates.hasListener, isFalse);
    });

    testWidgets('re-checks on the recheck interval', (tester) async {
      final service = await pumpGate(
        tester,
        recheckInterval: const Duration(hours: 1),
      );
      expect(service.evaluations, 1);

      await tester.pump(const Duration(hours: 1));
      expect(service.evaluations, 2);

      await tester.pumpWidget(_wrap(const SizedBox()));
    });

    testWidgets('unmount stops listening for config updates', (tester) async {
      final service = await pumpGate(tester, listen: true);
      expect(service.updates.hasListener, isTrue);

      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(service.updates.hasListener, isFalse);
    });
  });
}
