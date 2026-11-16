import 'package:flutter_test/flutter_test.dart';
import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/state.dart';
import 'package:reducer_view_model/ui_inputs.dart';

class SimpleUIInputs extends ReducerVMUIInputs {
  @override
  List<Object?> get props => [];
}

class TestVMState extends ReducerVMState<TestVMState, int, SimpleUIInputs, ({int value})> {
  final int value;
  final void Function(String) logSpy;

  const TestVMState({required this.value, required this.logSpy});

  @override
  void Function(String message) get log => logSpy;

  @override
  List<Object?> get props => [value];

  @override
  ({int value}) selectDependencies(ReducerViewModelInputs<int, SimpleUIInputs> inputs, TestVMState self) {
    return (value: inputs.blocStates);
  }

  @override
  TestVMState rebuildSelf({required ({int value}) dependencies}) {
    return TestVMState(value: dependencies.value, logSpy: logSpy);
  }

  @override
  TestVMState updateChildren({
    required ReducerViewModelInputs<int, SimpleUIInputs> previousInputs,
    required ReducerViewModelInputs<int, SimpleUIInputs> newInputs,
  }) {
    return this;
  }
}

void main() {
  group('ReducerVMState logging', () {
    test('calls log callback when rebuild occurs in currentOrNewFrom', () {
      final logs = <String>[];
      void spyLogger(String msg) {
        logs.add(msg);
      }

      final initialInputs = (blocStates: 1, ui: SimpleUIInputs());
      final state = TestVMState(value: 1, logSpy: spyLogger);

      final nextInputs = (blocStates: 2, ui: SimpleUIInputs());

      final newState = state.currentOrNewFrom(previousInputs: initialInputs, newInputs: nextInputs);

      expect(newState.value, 2);
      expect(logs.any((m) => m.contains('TestVMState')), isTrue);
    });

    test('does not call log callback when no rebuild occurs in currentOrNewFrom', () {
      final logs = <String>[];
      void spyLogger(String msg) {
        logs.add(msg);
      }

      final initialInputs = (blocStates: 1, ui: SimpleUIInputs());
      final state = TestVMState(value: 1, logSpy: spyLogger);

      final newState = state.currentOrNewFrom(previousInputs: initialInputs, newInputs: initialInputs);

      expect(newState, same(state));
      expect(logs, isEmpty);
    });
  });
}
