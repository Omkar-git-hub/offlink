import 'dart:async';
import 'package:flutter/widgets.dart';

class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager({
    AppLifecycleState initialState = AppLifecycleState.resumed,
  }) : _state = initialState;

  AppLifecycleState _state;
  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  bool _isObserving = false;

  AppLifecycleState get currentState => _state;

  Stream<AppLifecycleState> get lifecycleChanges => _controller.stream;

  bool get isForeground => _state == AppLifecycleState.resumed;

  bool get isBackground =>
      _state == AppLifecycleState.paused || _state == AppLifecycleState.hidden;

  bool get isInactive => _state == AppLifecycleState.inactive;

  void startObserving({WidgetsBinding? binding}) {
    if (_isObserving) return;
    try {
      final b = binding ?? WidgetsBinding.instance;
      b.addObserver(this);
      _isObserving = true;
    } catch (_) {
      // Fallback gracefully in test environments without active WidgetsBinding.
    }
  }

  void stopObserving({WidgetsBinding? binding}) {
    if (!_isObserving) return;
    try {
      final b = binding ?? WidgetsBinding.instance;
      b.removeObserver(this);
    } catch (_) {}
    _isObserving = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycleChange(state);
  }

  void handleLifecycleChange(AppLifecycleState newState) {
    if (_state == newState) return;
    _state = newState;
    _controller.add(newState);
  }

  void dispose() {
    stopObserving();
    _controller.close();
  }
}
