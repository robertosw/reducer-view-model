// # Technical Handoff
// Tests for `ReducerUIEventBus` implementing "smart" debounce.
//
// Features tested - see intent in event_bus.dart

import 'package:reducer_view_model/event_bus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

sealed class TestUIEvent {}

class EventDebouncedA extends TestUIEvent {
  final int value;

  EventDebouncedA(this.value);
}

class EventDebouncedB extends TestUIEvent {
  final int value;

  EventDebouncedB(this.value);
}

class EventImmediateC extends TestUIEvent {
  final int value;

  EventImmediateC(this.value);
}

class TestEventBus extends ReducerUIEventBus<TestUIEvent> {
  @override
  Set<Type> get debouncedTypes => {EventDebouncedA, EventDebouncedB};

  @override
  Duration get debounceDuration => const Duration(milliseconds: 150);

  @override
  final void Function(String value) log = print;
}

void main() {
  late TestEventBus bus;
  late List<TestUIEvent> receivedEvents;

  setUp(() {
    bus = TestEventBus();
    receivedEvents = [];
    bus.addListener((event) => receivedEvents.add(event));
  });

  tearDown(() {
    bus.disposeDebounce();
  });

  group('Multiple targets support', () {
    test('Multiple listeners react to events triggered by a single source', () {
      final secondReceived = <TestUIEvent>[];
      bus.addListener((event) => secondReceived.add(event));

      bus.dispatch(EventImmediateC(1));

      expect(receivedEvents.length, 1);
      expect(secondReceived.length, 1);
    });

    test('Anyone can add and remove listeners using addListener and removeListener', () {
      final tempReceived = <TestUIEvent>[];
      void tempListener(TestUIEvent e) => tempReceived.add(e);

      bus.addListener(tempListener);
      bus.dispatch(EventImmediateC(1));
      expect(tempReceived.length, 1);

      bus.removeListener(tempListener);
      bus.dispatch(EventImmediateC(2));
      expect(tempReceived.length, 1); // Not changed
    });
  });

  group('Debouncing of selected types (debouncedTypes)', () {
    group('If no debounce chain is active', () {
      test('The dispatched event is a different type than the previous event ➔ processed immediately', () {
        bus.dispatch(EventDebouncedA(1));
        bus.dispatch(EventDebouncedB(1));

        expect(receivedEvents.length, 2);
        expect((receivedEvents[0] as EventDebouncedA).value, 1);
        expect((receivedEvents[1] as EventDebouncedB).value, 1);
      });

      test(
        'The dispatched event is the same type as the previous event: duration < debounce duration ➔ waits',
        () {
          fakeAsync((async) {
            bus.dispatch(EventDebouncedA(1)); // Processed immediately
            bus.dispatch(EventDebouncedA(2)); // Chain starts, waits

            expect(receivedEvents.length, 1);

            async.elapse(const Duration(milliseconds: 150));

            expect(receivedEvents.length, 2);
            expect((receivedEvents[1] as EventDebouncedA).value, 2);
          });
        },
      );

      test(
        'The dispatched event is the same type as the previous event: duration >= debounce duration ➔ processed immediately',
        () {
          fakeAsync((async) {
            bus.dispatch(EventDebouncedA(1));

            async.elapse(const Duration(milliseconds: 151));
            bus.dispatch(EventDebouncedA(2));

            expect(receivedEvents.length, 2);
            expect((receivedEvents[0] as EventDebouncedA).value, 1);
            expect((receivedEvents[1] as EventDebouncedA).value, 2);
          });
        },
      );
    });

    group('A debounce chain is already active', () {
      test(
        'new event is same type as the debounce chain ➔ debounce timer is reset, new event has to wait',
        () {
          fakeAsync((async) {
            bus.dispatch(EventDebouncedA(1)); // Immediate
            bus.dispatch(EventDebouncedA(2)); // Starts chain
            bus.dispatch(EventDebouncedA(3)); // Replaces trailing candidate and resets timer

            expect(receivedEvents.length, 1);

            async.elapse(const Duration(milliseconds: 150));

            expect(receivedEvents.length, 2);
            expect((receivedEvents[1] as EventDebouncedA).value, 3);
          });
        },
      );

      test(
        'new event is different type as the debounce chain ➔ latest event of the chain is processed immediately, new event is delayed',
        () {
          fakeAsync((async) {
            bus.dispatch(EventDebouncedA(1)); // Immediate
            bus.dispatch(EventDebouncedA(2)); // Starts chain

            async.elapse(const Duration(milliseconds: 50));

            bus.dispatch(EventDebouncedB(1)); // Interrupts

            // A is flushed immediately
            expect(receivedEvents.length, 2);
            expect((receivedEvents[1] as EventDebouncedA).value, 2);

            // B waits one duration
            async.elapse(const Duration(milliseconds: 150));
            expect(receivedEvents.length, 3);
            expect((receivedEvents[2] as EventDebouncedB).value, 1);
          });
        },
      );
    });
  });

  group('Preserve chronological order of events in all cases', () {
    test('Non-debounced interrupts chain, flushes and starts new chain', () {
      fakeAsync((async) {
        bus.dispatch(EventDebouncedA(1)); // Immediate
        bus.dispatch(EventDebouncedA(2)); // Starts chain

        bus.dispatch(EventImmediateC(1)); // Interrupts

        // A flushed
        expect(receivedEvents.length, 2);
        expect((receivedEvents[1] as EventDebouncedA).value, 2);

        // C waits one duration
        async.elapse(const Duration(milliseconds: 150));
        expect(receivedEvents.length, 3);
        expect((receivedEvents[2] as EventImmediateC).value, 1);
      });
    });

    test('Non-debounced events process immediately when idle', () {
      bus.dispatch(EventImmediateC(1));
      bus.dispatch(EventImmediateC(2));

      expect(receivedEvents.length, 2);
      expect((receivedEvents[0] as EventImmediateC).value, 1);
      expect((receivedEvents[1] as EventImmediateC).value, 2);
    });

    test('Reentrant dispatch preserves order', () {
      fakeAsync((async) {
        bus.addListener((event) {
          if (event is EventDebouncedA && event.value == 1) {
            bus.dispatch(EventImmediateC(1));
          }
        });

        bus.dispatch(EventDebouncedA(1));

        expect(receivedEvents.length, 2);
        expect(receivedEvents[0] is EventDebouncedA, true);
        expect(receivedEvents[1] is EventImmediateC, true);
      });
    });

    test('Reentrant dispatch preserves order when chain active', () {
      fakeAsync((async) {
        bus.addListener((event) {
          if (event is EventDebouncedA && event.value == 2) {
            bus.dispatch(EventImmediateC(1));
          }
        });

        bus.dispatch(EventDebouncedA(1)); // Immediate
        bus.dispatch(EventDebouncedA(2)); // Chain starts

        bus.dispatch(EventDebouncedB(1)); // Flushes A2

        expect(receivedEvents.length, 3);
        expect((receivedEvents[0] as EventDebouncedA).value, 1);
        expect((receivedEvents[1] as EventDebouncedA).value, 2);
        expect((receivedEvents[2] as EventDebouncedB).value, 1);

        async.elapse(const Duration(milliseconds: 150));
        expect(receivedEvents.length, 4);
        expect((receivedEvents[3] as EventImmediateC).value, 1);
      });
    });
  });

  group('Safety & Snapshotting', () {
    test('Listener add/remove snapshot during emit', () {
      var lateListenerCalled = false;
      void lateListener(TestUIEvent e) {
        lateListenerCalled = true;
      }

      bus.addListener((event) {
        bus.addListener(lateListener);
        bus.removeListener(lateListener);
      });

      bus.dispatch(EventImmediateC(1));
      expect(lateListenerCalled, false);
    });
  });
}
