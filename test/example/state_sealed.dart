import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/state.dart';

import 'cubit.dart';

typedef Dependencies = ({bool isCheckboxAbcClicked, DateTime startDate});

sealed class VMStateSealed extends ReducerVMState<VMStateSealed, BlocInputs, UIInputs, Dependencies> {
  @override
  void Function(String message) get log => print;

  // ---------------------------------------------------------------------------------------------------
  static VMStateSealed initial({required ReducerViewModelInputs<BlocInputs, UIInputs> inputs}) {
    return inputs.ui.isCheckboxAbcClicked
        ? VMStateSealedPrimary._()
        : VMStateSealedSecondary._(selectedDate: inputs.blocStates.startDate);
  }
}

// ----------------------------------------------------------------------------------------------------

final class VMStateSealedPrimary extends VMStateSealed {
  VMStateSealedPrimary._();

  @override
  List<Object?> get props => [];

  @override
  Dependencies selectDependencies(ReducerViewModelInputs<BlocInputs, UIInputs> inputs, VMStateSealed self) {
    return (isCheckboxAbcClicked: inputs.ui.isCheckboxAbcClicked, startDate: inputs.blocStates.startDate);
  }

  @override
  VMStateSealed rebuildSelf({required Dependencies dependencies}) {
    if (dependencies.isCheckboxAbcClicked == false) {
      return VMStateSealedSecondary._(selectedDate: dependencies.startDate);
    }
    return VMStateSealedPrimary._();
  }

  @override
  VMStateSealedPrimary updateChildren({
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
  }) => this;
}

// ----------------------------------------------------------------------------------------------------

final class VMStateSealedSecondary extends VMStateSealed {
  final DateTime selectedDate;

  VMStateSealedSecondary._({required this.selectedDate});

  @override
  List<Object?> get props => [selectedDate];

  @override
  Dependencies selectDependencies(ReducerViewModelInputs<BlocInputs, UIInputs> inputs, VMStateSealed self) =>
      (isCheckboxAbcClicked: inputs.ui.isCheckboxAbcClicked, startDate: inputs.blocStates.startDate);

  @override
  VMStateSealed rebuildSelf({required Dependencies dependencies}) {
    if (dependencies.isCheckboxAbcClicked) return VMStateSealedPrimary._();
    return VMStateSealedSecondary._(selectedDate: dependencies.startDate);
  }

  @override
  VMStateSealedSecondary updateChildren({
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
  }) => this;
}
