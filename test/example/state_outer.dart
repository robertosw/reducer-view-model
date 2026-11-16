import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/state.dart';

import 'cubit.dart';
import 'state_inner.dart';
import 'state_sealed.dart';

class VMStateOuter extends ReducerVMState<VMStateOuter, BlocInputs, UIInputs, ({bool isCheckboxAbcClicked})> {
  @override
  void Function(String message) get log => print;

  final bool isCheckboxAbcClicked;
  final VMStateInner bodyData;
  final VMStateSealed sealedData;

  // ---------------------------------------------------------------------------------------------------
  @override
  List<Object?> get props => [isCheckboxAbcClicked, bodyData, sealedData];

  const VMStateOuter._({
    required this.isCheckboxAbcClicked,
    required this.bodyData,
    required this.sealedData,
  });

  // ---------------------------------------------------------------------------------------------------
  static VMStateOuter initial({required ReducerViewModelInputs<BlocInputs, UIInputs> inputs}) {
    return VMStateOuter._(
      isCheckboxAbcClicked: inputs.ui.isCheckboxAbcClicked,
      bodyData: VMStateInner.initial(inputs: inputs),
      sealedData: VMStateSealed.initial(inputs: inputs),
    ).rebuildSelf(dependencies: (isCheckboxAbcClicked: inputs.ui.isCheckboxAbcClicked));
  }

  // ---------------------------------------------------------------------------------------------------
  @override
  ({bool isCheckboxAbcClicked}) selectDependencies(
    ReducerViewModelInputs<BlocInputs, UIInputs> inputs,
    VMStateOuter self,
  ) => (isCheckboxAbcClicked: inputs.ui.isCheckboxAbcClicked);

  // ---------------------------------------------------------------------------------------------------
  @override
  VMStateOuter updateChildren({
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
  }) {
    final newBodyData = bodyData.currentOrNewFrom(previousInputs: previousInputs, newInputs: newInputs);
    final newSealedData = sealedData.currentOrNewFrom(previousInputs: previousInputs, newInputs: newInputs);

    final areChildrenIdentical = identical(newBodyData, bodyData) && identical(newSealedData, sealedData);

    return (areChildrenIdentical)
        ? this
        : VMStateOuter._(
            isCheckboxAbcClicked: isCheckboxAbcClicked,
            bodyData: newBodyData,
            sealedData: newSealedData,
          );
  }

  // ---------------------------------------------------------------------------------------------------
  @override
  VMStateOuter rebuildSelf({required ({bool isCheckboxAbcClicked}) dependencies}) {
    return VMStateOuter._(
      isCheckboxAbcClicked: dependencies.isCheckboxAbcClicked,
      bodyData: bodyData,
      sealedData: sealedData,
    );
  }
}
