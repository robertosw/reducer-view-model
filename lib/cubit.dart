import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reducer_view_model/event_bus.dart';
import 'package:reducer_view_model/state.dart';
import 'package:reducer_view_model/ui_inputs.dart';

typedef ReducerViewModelInputs<BlocInputs, UIInputs extends ReducerVMUIInputs> = ({
  BlocInputs blocStates,
  UIInputs ui,
});

/// # Usage
///
/// Example in the `test/example` directory
///
/// 1. Define a typedef record for [BlocInputs] and a class extending [ReducerVMUIInputs] for [UIInputs]
///    ```dart
///    typedef ExampleBlocInputs = ({StateClassA stateA, StateClassB stateB});
///
///    class ExampleUIInputs extends ReducerVMUIInputs {
///        final Object param1;
///
///       const ExampleUIInputs({required this.param1});
///
///       static final initial =  ExampleUIInputs(...);
///
///       ExampleUIInputs copyWith(...) { ... }
///    }
///    ```
/// 2. Define a sealed class for the [UIEvent]
///    ```dart
///    sealed class ExampleUIEvent {}
///
///    class EventClickCheckbox extends ExampleUIEvent {
///      final bool isCheckboxAbcClicked;
///
///      EventClickCheckbox({required this.isCheckboxAbcClicked});
///    }
///    ```
/// 3. Define your view model state class - see [ReducerVMState] docs
/// 4. Define your subclass
///    ```dart
///    class ExampleVMCubit
///        extends
///            ReducerVMCubit<
///              ExampleBlocInputs,
///              ExampleUIInputs,
///              ExampleUIEvent,
///              ReducerVMState,
///            > { ... }
///    ```
/// 5. Define your constructor:
///    ```dart
///    ExampleVMCubit({required super.initialBlocStates}) : super(
///            initialUiInputs: ExampleUIInputs.initial(),
///            buildInitialStateFrom: (inputs) => ExampleVMState.initial(inputs: inputs),
///          );
///    ```
///    - [initialBlocStates] has to be provided by the widget that creates this view model
///    - [initialUiInputs] have to be defined manually for each custom view model
/// 6. Define the remaining overrides
///    ```dart
///    @override
///    final ReducerUIEventBus eventBus = ReducerUIEventBus.instance;
///
///    @override
///    ExampleUIInputs uiInputsFromEvent(ExampleUIEvent event, ExampleUIInputs previousInputs) {
///      return switch (event) {
///        EventClickCheckbox() => ExampleUIInputs(param1: event.isCheckboxAbcClicked),
///      };
///    }
///    ```
/// # General concept
///
/// - To be used with [ReducerVMState] and [ReducerUIEventBus]
///
///
/// It turned out to be much simpler to deterministically regenerate the entire view model state from
/// uniformly structured "inputs" after every change, instead of iteratively adjusting only a small part
/// of it on every change.
///
/// This "inputs" structure is helpful / necessary because:
/// - Not every input value is stored 1:1 in the state. Some are transformed, so the original input
///   can no longer be restored from the state. However, the previous inputs are needed to rebuild as
///   little of the state as possible
/// - It reduces boilerplate, since a value like "isCheckboxAbcClicked" no longer has to be passed
///   through all constructors down to the lowest one that needs it
abstract class ReducerVMCubit<
  BlocInputs extends Record,
  UIInputs extends ReducerVMUIInputs,
  UIEvent,
  State extends ReducerVMState<State, BlocInputs, UIInputs, Record>
>
    extends Cubit<State> {
  @protected
  /// This cubit handles adding (constructor) and removing (on [close]) listeners to the eventBus for you
  abstract final ReducerUIEventBus<UIEvent> eventBus;

  ReducerViewModelInputs<BlocInputs, UIInputs> _previousInputs;

  ReducerVMCubit({
    required BlocInputs initialBlocStates,
    required UIInputs initialUiInputs,
    required State Function(ReducerViewModelInputs<BlocInputs, UIInputs> inputs) buildInitialStateFrom,
  }) : _previousInputs = (blocStates: initialBlocStates, ui: initialUiInputs),
       super(buildInitialStateFrom((blocStates: initialBlocStates, ui: initialUiInputs))) {
    eventBus.addListener(onUIEvent);
  }

  @override
  Future<void> close() {
    eventBus.removeListener(onUIEvent);
    return super.close();
  }

  /// Builds new inputs, emits a new state and updates [_previousInputs] with the new inputs.
  ///
  /// Override if you want to add custom logic (e.g. logging).
  /// ```dart
  /// @override
  /// void onBlocStateChange(BlocInputs blocStates) {
  ///   // your code here
  ///   super.onBlocStateChange(blocStates);
  /// }
  /// ```
  void onBlocStateChange(BlocInputs blocStates) {
    if (isClosed) return;
    final newInputs = (blocStates: blocStates, ui: _previousInputs.ui);
    final newState = state.currentOrNewFrom(previousInputs: _previousInputs, newInputs: newInputs);
    emit(newState);
    _previousInputs = newInputs;
  }

  /// Builds new inputs, emits a new state and updates [_previousInputs] with the new inputs.
  ///
  /// Override if you want to add custom logic (e.g. logging).
  /// ```dart
  /// @override
  /// void onUIEvent(UIEvent event) {
  ///   // your code here
  ///   super.onUIEvent(event);
  /// }
  /// ```
  void onUIEvent(UIEvent event) {
    if (isClosed) return;
    final newInputs = (
      blocStates: _previousInputs.blocStates,
      ui: uiInputsFromEvent(event, _previousInputs.ui),
    );
    final newState = state.currentOrNewFrom(previousInputs: _previousInputs, newInputs: newInputs);
    emit(newState);
    _previousInputs = newInputs;
  }

  /// Build a new instance of [UIInputs] from [previousInputs] and the new [UIEvent].
  ///
  /// This is the view-model **reducer** — the only logic that belongs in the cubit. It must be a pure
  /// function of `(event, previousInputs)`: no bloc calls, no navigation, no side effects. Those live
  /// in the widget's event listener (see `ReducerUIEventBus`).
  ///
  /// Convention — two event categories, decided by this method's return value:
  /// - **modification event**: returns new [UIInputs] (e.g. form value, process, hydration changes).
  ///   Guard forbidden mutations by returning [previousInputs] unchanged (silent deny).
  /// - **action event**: returns [previousInputs] unchanged. The reducer ignores it; the widget
  ///   owns the effect and guards it loudly (throw) if the VM policy forbids the action.
  ///
  /// Both layers may react to the same event — a modification event can mutate inputs here and reset
  /// blocs in the widget
  UIInputs uiInputsFromEvent(UIEvent event, UIInputs previousInputs);
}
