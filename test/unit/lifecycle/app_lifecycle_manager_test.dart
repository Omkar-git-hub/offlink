import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/lifecycle/app_lifecycle_manager.dart';

void main() {
  group('AppLifecycleManager', () {
    test('initializes with default resumed state and reflects foreground', () {
      final manager = AppLifecycleManager();

      expect(manager.currentState, equals(AppLifecycleState.resumed));
      expect(manager.isForeground, isTrue);
      expect(manager.isBackground, isFalse);
      expect(manager.isInactive, isFalse);

      manager.dispose();
    });

    test(
      'transitions to background when state becomes paused or hidden',
      () async {
        final manager = AppLifecycleManager();
        final transitions = <AppLifecycleState>[];
        final sub = manager.lifecycleChanges.listen(transitions.add);

        manager.handleLifecycleChange(AppLifecycleState.paused);
        expect(manager.isBackground, isTrue);
        expect(manager.isForeground, isFalse);

        manager.handleLifecycleChange(AppLifecycleState.hidden);
        expect(manager.isBackground, isTrue);

        await Future<void>.delayed(Duration.zero);
        expect(
          transitions,
          equals([AppLifecycleState.paused, AppLifecycleState.hidden]),
        );

        await sub.cancel();
        manager.dispose();
      },
    );

    test('transitions to inactive without destroying state', () async {
      final manager = AppLifecycleManager();
      final transitions = <AppLifecycleState>[];
      final sub = manager.lifecycleChanges.listen(transitions.add);

      manager.handleLifecycleChange(AppLifecycleState.inactive);
      expect(manager.isInactive, isTrue);
      expect(manager.isForeground, isFalse);
      expect(manager.isBackground, isFalse);

      await Future<void>.delayed(Duration.zero);
      expect(transitions, equals([AppLifecycleState.inactive]));

      await sub.cancel();
      manager.dispose();
    });

    test('transitions back to foreground when resumed', () async {
      final manager = AppLifecycleManager(
        initialState: AppLifecycleState.paused,
      );

      expect(manager.isBackground, isTrue);

      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(manager.isForeground, isTrue);
      expect(manager.isBackground, isFalse);

      manager.dispose();
    });

    test('ignores duplicate consecutive state transitions', () async {
      final manager = AppLifecycleManager();
      final transitions = <AppLifecycleState>[];
      final sub = manager.lifecycleChanges.listen(transitions.add);

      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.paused);

      await Future<void>.delayed(Duration.zero);
      expect(transitions, hasLength(1));

      await sub.cancel();
      manager.dispose();
    });
  });
}
