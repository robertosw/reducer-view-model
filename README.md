# reducer_view_model

Build the view state of a Flutter route as a pure function of its bloc states and UI inputs.

# Why

## The problem

I used to have one large Bloc per route. It ran all API requests, kept their states internally and had
public methods that the UI called for each user interaction. Request handling, UI state and policy ("is
this action allowed now?" checks) were all mixed in one class. This caused:

- **Inconsistent states**: each method changed only a part of the state, so some combinations of requests
  and user input led to states that should not exist.
- **High test effort**: to test one interaction, you had to set up the complete bloc with all its
  requests.
- **High cognitive load**: to change one behavior, you had to understand all the surrounding logic.

## The approach

Each part of a route has one job:

- **One request bloc per API endpoint.** It only tracks the state of its request (for example idle,
  loading, failure, empty, data available). These blocs are not part of this package; any bloc works.
- **A view model state that is a pure function of its inputs.** [ReducerVMState](lib/state.dart) is
  rebuilt from the bloc states and UI inputs after each change. It is never patched step by step. The
  same inputs always give the same state, and sealed state classes make each possible state explicit.
  Only the parts of the state tree whose declared dependencies changed are rebuilt.
- **A policy per view model.** Extension getters on the view model states answer "is this action
  allowed now?" (for example: is this button enabled?). Widgets read them; they do not compute it.
- **A reducer.** [ReducerVMCubit](lib/cubit.dart) turns UI events into new UI inputs. It has no side
  effects.
- **An event bus.** [ReducerUIEventBus](lib/event_bus.dart) sends each UI event to the reducer and to the
  widget. The widget runs the side effects (requests, navigation).

The result is a complete state machine per route. You test it by giving inputs and checking the resulting
state and policy getters, without widgets or network calls.

## Why an event bus

- The cubit does not need one public method per interaction. All events go through one `switch` in
  `uiInputsFromEvent`.
- Widgets dispatch events without looking up the cubit in the `BuildContext`.
- You can debounce selected event types, and events are always processed in the order they were
  dispatched.

## When to use it

- **Two or more API requests plus user interactions**: this is where the package helps most.
- **One API request**: about the same effort as a custom bloc. Using it anyway keeps one structure
  across the whole codebase.
- **No API requests or other async code**: you do not need it. Keep the logic in a `StatefulWidget`.

# Docs

Docs are inside the Dart files on the classes themselves:

- [ReducerVMCubit](lib/cubit.dart)
- [ReducerVMState](lib/state.dart)
- [ReducerUIEventBus](lib/event_bus.dart)

# Usage

see the '[designing-view-models](.pi/skills/designing-view-models.md)' skill

# Changelog

see [Changelog](CHANGELOG.md)