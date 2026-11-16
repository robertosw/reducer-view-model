import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/event_bus.dart';
import 'package:reducer_view_model/ui_inputs.dart';

import 'events.dart';
import 'state_outer.dart';

typedef BlocInputs = ({DateTime startDate});

class UIInputs extends ReducerVMUIInputs {
  final bool isCheckboxAbcClicked;

  const UIInputs({required this.isCheckboxAbcClicked});

  @override
  List<Object?> get props => [isCheckboxAbcClicked];
}

/// Some class defined in your project

class VMCubit extends ReducerVMCubit<BlocInputs, UIInputs, UIEvent, VMStateOuter> {
  @override
  VMCubit({required super.initialBlocStates})
    : super(
        initialUiInputs: const UIInputs(isCheckboxAbcClicked: false),
        buildInitialStateFrom: (inputs) => VMStateOuter.initial(inputs: inputs),
      );

  @override
  ReducerUIEventBus<UIEvent> get eventBus => UIEventBus.instance;

  @override
  UIInputs uiInputsFromEvent(UIEvent event, UIInputs previousInputs) {
    return switch (event) {
      EventClickCheckbox() => UIInputs(isCheckboxAbcClicked: event.isCheckboxAbcClicked),
    };
  }
}
