---
name: designing-view-models
description: Create or change the view model of a route built with reducer_view_model - ReducerVMState
  hierarchies, policy getters, UI events, the reducer and the controller. Use before writing or changing
  anything in view_model/, or the widget.dart of a route with a ReducerVMCubit.
---

# Layers: state, reducer, controller

A `ReducerVMCubit` route has three cooperating layers. Deciding which logic goes where is a common
sticking point.

1. **View model state** (`view_model/state.dart`, `policy.dart`, `validation_state.dart`): the current
   truth. A pure deterministic function of `(blocStates, uiInputs)`. Never calls blocs, never routes,
   never shows UI. `policy.dart` holds the getters that answer "is this action allowed right now" (see
   [View model policy](#view-model-policy)).
2. **`cubit.dart`**: the event reducer. `uiInputsFromEvent` is the only logic that belongs here. Never
   add side effects here.
   - Input-change events: an event the policy forbids returns `previousInputs` unchanged (silent deny).
   - Action events: no-op, returns `previousInputs`. `widget.dart` owns them.
3. **`widget.dart`**: the controller. Owns the blocs and all side effects. It is the only place that
   starts requests on / resets blocs, navigates and resets one bloc in response to another.
   An action event the policy forbids is a UI bug: throw loud (e.g. `ArgumentError`). The server would
   reject it anyway; throwing locally yields a stack trace instead of a silent stuck screen.

Widgets guard even earlier (**guard-before-dispatch**): a button reads one policy getter and passes
`null` to `onPressed` when it is false, so forbidden events are never dispatched. A compound `if` inside
a widget that decides enablement belongs into a single policy getter, so the widget stays dumb and the
condition stays testable.

## Event-driven side effects

When something must happen (reset a bloc, start a request, navigate), `widget.dart` reacts to the event
in its event bus listener, not via a `BlocListener` on the cubit's emitted state. This was chosen for
immediacy and predictable ordering.

Both the reducer and `widget.dart` listen to the whole event bus, so **both may react to the same
event**. The event category (input change vs action) only constrains the reducer. An input-change event
may change inputs in `cubit.dart` and reset a bloc in `widget.dart` at the same time; that is intended.

# View model state hierarchy

## Implementing the projection

Full documentation is in the doc comments of `package:reducer_view_model` (`lib/`).

- `selectDependencies` copies the inputs slice the state consumes into `Dependencies` (no logic)
- `rebuildSelf` picks the state class from `Dependencies`. A factory `from` per family encodes the
  priority by branch order. See 'Cascading factory constructors' below.
- `updateChildren` rebuilds child states and returns `this` when every child is `identical` to the
  previous one. Returning a new instance re-emits the cubit state; identity is the no-change signal.
- `props` lists every field: base classes expose a `_props` helper, leaves extend it:
  `[...super._props, requestState]`

## Distinct disjoint states

Large decisions that affect the entire view should be distinct substates of the sealed VMState. Example:
a login route: The entire view either allows the user to input login data and submit
to log in OR allows the user to input his username and submit to receive a password-reset e-mail. These
two share no state, so they should be distinct classes:

```dart
sealed class VMState extends ReducerVMState<...> {}

sealed class VMStateLogin extends VMState {}

sealed class VMStateReset extends VMState {} 
```

Each subclass should carry only the fields it needs.

## Shared process state as parameter

Sometimes, multiple states share a process that itself should be expressed as states.

Example: a details route whose `VMState` has many substates. These represent the different ways the user can view the same data. All
views allow the user start a validate-then-submit flow. That flow has many states itself (Idle, Loading,
Waiting for Submit, Loading, Finished) that are identical between the three views of the route. In such
cases, define the flow state as a parameter of the view states.

```dart
// in file 1
sealed class VMValidationState extends Equatable {}

// in file 2
class VMStateA extends VMState {
  final VMValidationState validationState;
}

class VMStateB extends VMState {
  final VMValidationState validationState;
}
```

## Choosing between parameter and classes

The flow state is a **parameter** when the views share the same data and the flow only changes parts of
the view (buttons, banners, disabled states).

The flow state is a **class discriminator** when each phase replaces the entire view with different
content and different fields (spinner screen, error page, success page).

When neither criterion clearly applies, weigh both options and present a short comparison in the session
chat. State your recommendation and ask the user before implementing. Do not pick silently.

## Cascading factory constructors

The top `VMState` picks the family in `rebuildSelf` and defines no `from` factory. Each sealed class
*below* it defines a `factory VMStateABC.from(VMDependencies)` that picks the next level. Only the
deepest classes return real instances. This way each sealed class must only implement the logic that is
necessary to decide which subclass to delegate construction to.

```dart
sealed class VMState extends ReducerVMState<...> {
  @override
  @protected
  VMState rebuildSelf({required VMDependencies dependencies}) =>
      (dependencies.showsResetForm)
          ? VMStateReset.from(dependencies)
          : VMStateLogin.from(dependencies);
}

sealed class VMStateReset extends VMState {
  VMStateReset();

  factory VMStateReset.from(VMDependencies dependencies) {
    /// logic to pick a concrete sub class to instantiate
    return switch (dependencies.resetState) {
      RequestFailure() => VMStateResetFailed(),
      RequestLoading() => VMStateResetLoading(),
      RequestSuccess() => VMStateResetSuccess(),
      _ => VMStateResetIdle(),
    };
  }
}

sealed class VMStateLogin extends VMState {
  VMStateLogin();

  factory VMStateLogin.from(VMDependencies dependencies) {
    /// logic to pick a concrete sub class to instantiate
    return switch (dependencies.parameterA) {
      TypeA() => VMStateLoginFailure(),
      _ => VMStateLoginSuccessful(),
    };
  }
}
```

# View model policy

Defines extensions on view model states that hold centralized boolean getters. These getters tell the
widgets what is possible / allowed next.

Every getter is defined on the narrowest applicable VMState subclass ⇒ multiple extensions per file are
explicitly allowed.

## Naming

- `can<X>` = startable action
- `allows<X>` = input mutation accepted

## One getter, three readers

Each getter is the single source of truth for its control; no layer re-derives the condition. The widget
guards before dispatch, the reducer silently denies, the controller throws (see
[Layers](#layers-state-reducer-controller)).

## Positive examples

Policies represent "is an action or mutation accepted".

```dart
extension VMPolicy on VMState {
  bool get canOpenResetForm =>
      switch (this) {
        VMStateLoginLoading() => false,
        VMStateLoginForm() => true,
        _ => false,
      };
}

extension VMLoginPolicy on VMStateLogin {
  // switch is preferred. one- and two-state conditions may use is / is!
  bool get allowsFormValueChanges => this is! VMStateLoginLoading && this is! VMStateLoginSuccess;
}

extension VMResetPolicy on VMStateReset {
  bool get canConfirmReset =>
      switch (this) {
        VMStateResetLoading() => false,
        VMStateResetForm(hasUsernameText: true) => true,
        _ => false,
      };
}
```

## Negative examples

These belong into `state.dart`, not into `policy.dart`.

### Helpers

Helpers represent "is the state in condition X".

```dart
String? get failureMessage =>
    switch (this) {
      VMStateLoginFailed(:final message) => message,
      VMStateUserInfoFailed(:final message) => message,
      _ => null,
    };
```

Might be useful when building a centralized message-display-widget if there are different states that
contain user messages. Returns the message based on the current state if available. Does not belong into
`policy.dart`, belongs into `state.dart`

### Simplified state checks

```dart
bool get isGuarding => this is! VMStateLoginSuccess;
```

Might be useful if this check is performed a lot of times or if there are multiple conditions necessary.
Does not belong into `policy.dart`, belongs into `state.dart`

# View model events

## Naming

An event names **what happened** at its source, in the past tense. It never names what a listener
should do with it: several listeners react to the same event (reducer and `widget.dart`, see
`ReducerUIEventBus`), and each one decides on its own what the event means for it.

| Source                               | Pattern                                | Example                                   |
|--------------------------------------|----------------------------------------|-------------------------------------------|
| user changed a value                 | `…Changed`                             | `DetailsVMMasterDataFieldChanged`         |
| user selected or opened something    | `…Selected` / `…Opened`                | `DetailsVMTabSelected`                    |
| user asked for an action             | `…Requested`                           | `DetailsVMMasterDataSaveRequested`        |
| controller or bloc reports a fact    | `…Started` / `…Succeeded` / `…Failed`  | `DetailsVMMasterDataLoadStarted`          |
| another route reports a fact         | the fact itself                        | `FacilitiesVMFacilitySavedOrCreated`      |

Negative examples: `ChangeSelectedTab`, `RequestSave`, `CancelEdit`, `ClearDraft`, `RequestReload`.
They are commands: they hide the source and fix the reaction in the name. `RequestReload` from another
route tells the list what to do; `FacilitySavedOrCreated` reports the fact and the list decides to
reload.