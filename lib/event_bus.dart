import 'dart:async';

/// # Intent
///
/// - Enable multiple targets (e.g. cubits / blocs) to react to events triggered by a single source
///   (e.g. widgets)
///
/// - Support debouncing of selected types ([debouncedTypes])
///   - No debounce chain is active
///     - The dispatched event is a different type than the previous event:
///       ➔ Event is processed immediately
///     - The dispatched event is the same type as the previous event:
///       The duration between the two dispatch-timestamps is:
///       - smaller than one debounce duration ➔ debounce chain started, new event has to wait
///       - larger than one debounce duration ➔ new event is processed immediately
///   - A debounce chain is already active
///     - new event is same type as the debounce chain
///       ➔ debounce timer is reset, new event has to wait
///     - new event is different type as the debounce chain
///       ➔ latest event of the chain is processed immediately, new event is delayed by one debounce
///         duration (independent of if it is part of [debouncedTypes] or not)
///
/// - Preserve chronological order of events in all cases, no matter if incoming events are in
///   the [debouncedTypes] Set or not
///
/// - Anyone can add and remove listeners using [addListener] and [removeListener]
///
/// # Multiple listeners: reducer and side-effect handlers
///
/// A route typically registers two kinds of listeners on the same bus:
/// - the view-model reducer (`ReducerVMCubit.onUIEvent`), which folds an event into [UIInputs], and
/// - the route's widget, which runs side effects (network requests, bloc resets).
///
/// Both receive every dispatched event. Side effects are therefore **event-driven** through this bus,
/// not state-driven (no `BlocListener` on the cubit's emitted state). One dispatch can mutate inputs
/// AND trigger side effects at the same time; that dual handling is intended.
///
/// An event's category (modification vs action — see `ReducerVMCubit.uiInputsFromEvent`) only constrains
/// the reducer's (`cubit.dart` `uiInputsFromEvent`) contract. It does not gate which listeners may react.
///
/// # Naming events
///
/// Name an event after what happened at its source, in the past tense (`SearchChanged`,
/// `SaveRequested`, `LoadStarted`), not after what a listener should do with it (`ChangeSearch`,
/// `RequestReload`, `ClearDraft`): every listener decides on its own how to react.
///
/// # Usage
///
/// Define your subclass with a private constructor, `instance` getter, and debounced types:
/// ```dart
/// class FeatureUIEventBus extends ReducerUIEventBus<FeatureUIEvent> {
///   FeatureUIEventBus._();
///
///   static final FeatureUIEventBus instance = FeatureUIEventBus._();
///
///   @override
///   Set<Type> get debouncedTypes => {
///       FeatureUIEventResize,
///       FeatureUIEventTextChange
///   };
/// }
/// ```
///
/// # Why listeners are notified synchronously (and not via `scheduleMicrotask`)
///
/// Listeners are invoked synchronously in [_process]. Wrapping each call in
/// `scheduleMicrotask(() => listener(event))` was considered and rejected.
///
/// What it does NOT solve:
/// - Dart is single-threaded. A listener doing heavy *synchronous* work blocks the event loop
///   regardless of scheduling. `scheduleMicrotask` only defers *when* a listener runs - it does not
///   run it in parallel or off-thread. Heavy compute still freezes the UI.
///   ➔ Real fix: move heavy work off-thread inside the listener via `Isolate.run` / `compute`.
///
/// Disadvantages of `scheduleMicrotask` per listener:
/// - Breaks the [_isProcessing] guard: the `finally` clears the flag before the microtasks run,
///   making the reentrancy protection and [_reentrantQueue] ineffective.
/// - Breaks ordering guarantees: the debounce / chain logic assumes a synchronous [_process].
///   Async scheduling lets new dispatches interleave, so the chronological-order intent (a core
///   purpose of this class) is lost.
/// - Exceptions become async / uncaught: no longer thrown in the [dispatch] call stack, making them
///   harder to catch, log and test.
/// - Microtask flooding: the microtask queue fully drains before I/O / render; many listeners x many
///   events can starve the loop and delay frames anyway.
/// - No real parallelism gain: it only defers timing; the synchronous CPU cost is unchanged.
abstract class ReducerUIEventBus<UIEvent> {
  final _listeners = <void Function(UIEvent)>[];

  abstract final void Function(String value) log;

  /// Types of events that should be debounced.
  /// All other event types bypass the debounce and are processed immediately.
  ///
  /// > `!WARNING`
  /// > If two "valid" events of the same type get dispatched in quick succession - they are affected
  /// > by the debounce - even if both were meant to have an effect.
  /// > There is no way other than the [Type] to differentiate.
  /// >
  /// > Example: Your Event is used to update a form that has a date and some text. You debounce this
  /// > event so that you can send every keystroke and keep your UI code clean. If the user now selects
  /// > a different date and starts typing (both in quick succession) the newly selected date will never
  /// > be processed.
  ///
  /// Keep the events defined here as slim / precise as possible to avoid this.
  ///
  /// > `!WARNING 2`
  /// > Generic Types are matched exactly.
  /// > `MyType<int>` and `MyType<String>` are not treated as the same type and do not match `MyType`
  Set<Type> get debouncedTypes;

  /// Duration to wait before processing trailing debounced events.
  Duration get debounceDuration => const Duration(milliseconds: 50);

  Type? _activeChainType;
  Type? _lastDispatchType;
  Timer? _timeWindowTimer;
  Timer? _chainTimer;
  UIEvent? _pendingEvent;

  bool _isProcessing = false;
  final _reentrantQueue = <UIEvent>[];

  void addListener(void Function(UIEvent event) listener) => _listeners.add(listener);

  void removeListener(void Function(UIEvent event) listener) => _listeners.remove(listener);

  // ----------------------------------------------------------------------------------------------------
  void dispatch(UIEvent event) {
    if (_isProcessing) {
      _reentrantQueue.add(event);
      return;
    }

    final Type type = event.runtimeType;
    final bool isDebouncedType = debouncedTypes.contains(type);
    final bool isDebounceChainActive = _activeChainType != null;

    /// A debounce chain is already active
    if (isDebounceChainActive) {
      /// new event is same type as the debounce chain
      /// ➔ debounce timer is reset, new event has to wait
      if (_activeChainType == type) {
        _pendingEvent = event;
        _restartChainTimer();
      }
      /// new event is different type as the debounce chain
      /// ➔ latest event of the chain is processed immediately, new event is delayed by one debounce
      ///   duration (independent of if it is part of [debouncedTypes] or not)
      else {
        _flushChain();
        _startChain(type, event);
      }
    }
    /// No debounce chain is active
    else {
      final isSameType = _lastDispatchType == type;
      final isWithinWindow = _timeWindowTimer != null && _timeWindowTimer!.isActive;

      /// The dispatched event is the same type as the previous event AND the duration between the
      /// two dispatch-timestamps is smaller than one debounce duration
      /// ➔ debounce chain started, new event has to wait
      if (isDebouncedType && isSameType && isWithinWindow) {
        _startChain(type, event);
      }
      /// The dispatched event is a different type than the previous event:
      /// ➔ new event is processed immediately
      ///
      /// The dispatched event is the same type as the previous event AND the duration between the two
      /// dispatch-timestamps is larger than one debounce duration
      /// ➔ new event is processed immediately
      else {
        _process(event);
      }
    }

    _lastDispatchType = type;
    _restartWindowTimer();
    _drainReentrantQueue();
  }

  // ----------------------------------------------------------------------------------------------------
  void _startChain(Type type, UIEvent event) {
    _activeChainType = type;
    _pendingEvent = event;
    _restartChainTimer();
  }

  // ----------------------------------------------------------------------------------------------------
  void _restartChainTimer() {
    _chainTimer?.cancel();
    _chainTimer = Timer(debounceDuration, _onChainTimerFired);
  }

  // ----------------------------------------------------------------------------------------------------
  void _restartWindowTimer() {
    _timeWindowTimer?.cancel();
    _timeWindowTimer = Timer(debounceDuration, () {});
  }

  // ----------------------------------------------------------------------------------------------------
  void _onChainTimerFired() {
    final event = _pendingEvent;
    _pendingEvent = null;
    _activeChainType = null;

    if (event != null) {
      _process(event);
    }
    _drainReentrantQueue();
  }

  // ----------------------------------------------------------------------------------------------------
  void _flushChain() {
    _chainTimer?.cancel();
    final event = _pendingEvent;
    _pendingEvent = null;
    _activeChainType = null;

    if (event != null) {
      _process(event);
    }
  }

  // ----------------------------------------------------------------------------------------------------
  void _process(UIEvent event) {
    _isProcessing = true;
    try {
      log("$runtimeType => processing ${event.runtimeType}");
      final snapshot = List.of(_listeners);
      for (final listener in snapshot) {
        listener(event);
      }
    } finally {
      _isProcessing = false;
    }
  }

  // ----------------------------------------------------------------------------------------------------
  void _drainReentrantQueue() {
    while (_reentrantQueue.isNotEmpty) {
      final next = _reentrantQueue.removeAt(0);
      dispatch(next);
    }
  }

  // ----------------------------------------------------------------------------------------------------
  void disposeDebounce() {
    _chainTimer?.cancel();
    _timeWindowTimer?.cancel();
    _chainTimer = null;
    _timeWindowTimer = null;
    _pendingEvent = null;
    _activeChainType = null;
    _lastDispatchType = null;
    _reentrantQueue.clear();
    _isProcessing = false;
  }
}
