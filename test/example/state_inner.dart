import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/state.dart';

import 'cubit.dart';

class VMStateInner extends ReducerVMState<VMStateInner, BlocInputs, UIInputs, ({DateTime startDate})> {
  @override
  void Function(String message) get log => print;

  final DateTime selectedDate;

  // ---------------------------------------------------------------------------------------------------
  @override
  List<Object?> get props => [selectedDate];

  const VMStateInner._({required this.selectedDate});

  // ---------------------------------------------------------------------------------------------------
  static VMStateInner initial({required ReducerViewModelInputs<BlocInputs, UIInputs> inputs}) =>
      VMStateInner._(selectedDate: inputs.blocStates.startDate);

  // ---------------------------------------------------------------------------------------------------
  @override
  ({DateTime startDate}) selectDependencies(
    ReducerViewModelInputs<BlocInputs, UIInputs> inputs,
    VMStateInner self,
  ) => (startDate: inputs.blocStates.startDate);

  // ---------------------------------------------------------------------------------------------------
  @override
  VMStateInner rebuildSelf({required ({DateTime startDate}) dependencies}) {
    return VMStateInner._(selectedDate: dependencies.startDate);
  }

  // ---------------------------------------------------------------------------------------------------
  @override
  VMStateInner updateChildren({
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
  }) => this;
}
