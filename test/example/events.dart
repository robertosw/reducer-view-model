import 'package:reducer_view_model/event_bus.dart';

sealed class UIEvent {}

class EventClickCheckbox extends UIEvent {
  final bool isCheckboxAbcClicked;

  EventClickCheckbox({required this.isCheckboxAbcClicked});
}

class UIEventBus extends ReducerUIEventBus<UIEvent> {
  UIEventBus._();

  static final UIEventBus instance = UIEventBus._();

  @override
  Set<Type> get debouncedTypes => {EventClickCheckbox};

  @override
  final void Function(String value) log = print;
}
