## 1.1.1

* `ReducerVMState.currentOrNewFrom` now logs the **NEW** state type that has been created, rather than logging the old type and then returning the newly built

## 1.1.0

* `ReducerUIEventBus` now defined `abstract final` `log` method that implementations must override

## 1.0.0

* Replaced `needsRebuild` + `rebuildSelf(previousInputs, newInputs, settings)` with:
  * `selectDependencies(inputs) → Deps` — single source of truth for input dependencies
  * `rebuildSelf({required Deps dependencies, required Settings settings})` — rebuild using typed deps
* Added `Deps extends Record` type parameter to `ReducerVMState`
* `needsRebuild` comparison is now automatic via `==` on the `Deps` record (structural equality)
* `selectDependencies` allows to depend on inputs and computed values of the children
* Introduced Type Parameter `Self` (f-bounded polymorphism) to simplify declaration, usage and type checking

## 0.0.3

* Redesigned `ReducerVMState` rebuild mechanism for O(n) performance instead of O(n²)
  * Replaced `rebuild(...)` with two methods: `updateChildren(...)` and `rebuildSelf(...)`
  * Each state's `needsRebuild` is now called exactly once (bottom-up resolution)
  * Parent states now only check their own input conditions in `needsRebuild` — child conditions are automatically propagated
  * updated class documentation in `ReducerVMState`

## 0.0.2

* Cubit now uses `abstract class ReducerVMUIInputs` as Type Parameter `UIInputs` instead of relying on it being a Record. This is more practical
* `ReducerVMCubit` now has `State` as Type Parameter. This ensures that `blocTest` etc. continue to work as expected by users of the `bloc` package

## 0.0.1

* Initial release
  * `ReducerVMCubit<ExternalBlocStates, UIInputs, Settings, UIEvent>`
  * `ReducerVMState<ExternalBlocStates, UIInputs, Settings>`
  * `ReducerUIEventBus<UIEvent>`
