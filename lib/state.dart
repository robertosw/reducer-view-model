import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:reducer_view_model/cubit.dart';
import 'package:reducer_view_model/ui_inputs.dart';

/// # Usage
///
/// 1. Use the typedef record for [BlocInputs]
///    and the implementation for [UIInputs]
///     **from the cubit** to define your subclass. (see [ReducerVMCubit] docs).
///    [Dependencies] is a Dart record containing all inputs this state's **own** fields depend on.
///    ```dart
///    class ExampleVMState
///        extends
///            ReducerVMState<
///              ExampleVMState,
///              ExampleBlocInputs,
///              ExampleUIInputs,
///              ({bool someField})
///            > { ... }
///    ```
///    For complex dependency records, use a typedef:
///    ```dart
///    typedef ExampleDependencies = ({
///        bool someField,
///        DateTime date,
///        String name
///    });
///
///    class ExampleVMState
///        extends
///            ReducerVMState<
///              ExampleVMState,
///              ExampleBlocInputs,
///              ExampleUIInputs,
///              ExampleDependencies
///            > { ... }
///    ```
/// 2. Define the parameters, [Equatable] props & create a private constructor
///    ```dart
///    final stateParam1;
///    final stateParam2;
///
///    @override
///    List<Object?> get props => ...;
///
///    ExampleVMState._({required this.stateParam1, required this.stateParam2});
///    ```
///    It is recommended to make the constructor of this class private to ensure all users properly
///    call [currentOrNewFrom].
/// 3. Override [selectDependencies] and [rebuildSelf]
///
///    The base class automatically compares `selectDependencies(previousInputs, this)` with
///    `selectDependencies(newInputs, selfWithUpdatedChildren)` using `==` (Dart records have
///    structural equality).
///
///    This ensures you cannot forget to check a dependency — if you read it in [rebuildSelf],
///    you must have declared it in [selectDependencies].
/// 4. Override [updateChildren]
///
///    This resolves children bottom-up before own fields are checked, ensuring each
///    state's [selectDependencies] is called exactly **once**.
/// 5. Create a static `initial` method where you first create an instance on the simplest way possible
///    (the values used do not matter) and then call `rebuildSelf` on this instance.
///
///    This way, no logic is dublicated but only defined in `rebuildSelf`
///    ```dart
///    static ExampleVMState initial({
///      required ReducerViewModelInputs<BlocInputs, UIInputs> inputs,
///    }) {
///      final self = ExampleVMState._( ... );
///      return self.rebuildSelf(
///          dependencies: self.selectDependencies(inputs, self),
///      );
///    }
///    ```
/// 6. Use `.initial` in the constructor of classes that define this class as a parameter
///    (e.g. in the constructor of the view model cubit or in parent view model state classes)
abstract class ReducerVMState<
  Self extends ReducerVMState<Self, BlocInputs, UIInputs, Dependencies>,
  BlocInputs,
  UIInputs extends ReducerVMUIInputs,
  Dependencies extends Record
>
    extends Equatable {
  const ReducerVMState();

  /// Logging method provided by subclasses to output rebuild messages or debug logs.
  @protected
  void Function(String message) get log;

  /// - Extract all inputs into a record that this state needs to build its **own** fields
  /// - DO NOT include inputs that ONLY your children need. You can include them if you need them as well
  /// - If you depend on values computed by your children, use `self` instead of `this` to include them
  ///   in the record
  ///
  /// This method also works as a "*does this class need a rebuild*" check:
  ///
  /// The base class compares `selectDependencies(previousInputs, this)` with
  /// `selectDependencies(newInputs, selfWithUpdatedChildren)` using `==` to determine if a rebuild is
  /// needed. Dart records have structural equality, so this comparison works automatically.
  ///
  /// #### Example
  /// - You depend on `inputs.blocStates.startDate` and on `visibleDays` that is computed by your child.
  /// - Your child depends on `inputs.blocStates.startDate` and `inputs.ui.width`
  ///
  /// You would then return
  /// ```dart
  /// (
  ///   startDate: inputs.blocStates.startDate,
  ///   visibleDays: self.child.visibleDays
  /// )
  /// ```
  /// which does not include the parameter `inputs.ui.width` only your child depends on!
  @protected
  Dependencies selectDependencies(ReducerViewModelInputs<BlocInputs, UIInputs> inputs, Self self);

  /// Build a new instance of this state where it's **own** fields are updated.
  /// Pass all children directly from `this`.
  ///
  /// Use ONLY the values from [dependencies] to rebuild your **own** fields - not `this`!
  /// If you need more values, expand your own [Dependencies].
  ///
  /// [dependencies] contains exactly the values declared in [selectDependencies].
  ///
  /// When this is called, child state fields on `this` are already up-to-date
  /// (resolved by [updateChildren] beforehand). Simply read them from `this`.
  ///
  /// #### Example
  /// ```dart
  /// return YourClass._(
  ///   /// Build your own fields using only
  ///   /// the values from `dependencies`
  ///   yourField1: dependencies.abc,
  ///   yourField2: dependencies.xzy,
  ///
  ///   /// This is wrong and will lead to
  ///   /// rebuild-bugs at runtime!
  ///   yourField3: this.child1.abc,
  ///
  ///   /// Your children are already updated,
  ///   /// use them directly in the constructor
  ///   child1: this.child1,
  ///   child2: this.child2,
  /// );
  /// ```
  @protected
  Self rebuildSelf({required Dependencies dependencies});

  /// Override this to resolve child [ReducerVMState] fields bottom-up.
  ///
  /// ### Leaf states
  /// **= states without [ReducerVMState] children / parameters**
  ///
  /// return `this`
  ///
  /// ### states with [ReducerVMState] children / parameters
  /// Call [currentOrNewFrom] on each child. If any child returned a new instance,
  /// return a new instance of this state with the updated children (keeping own fields unchanged).
  /// If no child changed, return `this`.
  ///
  /// ##### Example
  /// ```dart
  /// final newStateParam1 = stateParam1.currentOrNewFrom(
  ///   previousInputs: previousInputs,
  ///   newInputs: newInputs,
  /// ) as VMStateParam1;
  /// // ^^^ ... do the same for each
  /// // ^^^ parameter that extends ReducerVMState
  ///
  /// // Compare all for identity
  /// final areChildrenIdentical = identical(newStateParam1, stateParam1);
  ///
  /// return (areChildrenIdentical)
  ///     ? this
  ///     : VMStateSelf._(
  ///           boolParam1: boolParam1,
  ///           stateParam1: newStateParam1
  ///       );
  /// ```
  @protected
  Self updateChildren({
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
  });

  /// Returns the current instance if nothing of importance to this or its children changed.
  ///
  /// ### Flow
  /// 1. Resolves children bottom-up via [updateChildren]
  /// 2. Checks if any child returned a new instance (via [identical])
  /// 3. Compares [selectDependencies] for previous vs new inputs
  /// 4. If either changed, calls [rebuildSelf] on the children-updated instance
  ///
  /// ### Example-Flow
  /// Only C has changes but this correctly causes A and B to also return a new instance
  ///
  /// ```
  /// A.currentOrNewFrom:
  ///   ├─ A.updateChildren:
  ///   │    └─ B.currentOrNewFrom:
  ///   │         ├─ B.updateChildren:
  ///   │         │    └─ C.currentOrNewFrom:
  ///   │         │         ├─ C.updateChildren → this (leaf, no children)
  ///   │         │         ├─ C.selectDependencies(prev) != C.selectDependencies(new) → true
  ///   │         │         └─ C.rebuildSelf → newC ✓
  ///   │         ├─ !identical(oldC, newC) → true (childrenChanged)
  ///   │         ├─ B.selectDependencies(prev) == B.selectDependencies(new) → no rebuild
  ///   │         └─ return withUpdatedChildren (B with newC) ✓
  ///   ├─ !identical(oldB, newB) → true (childrenChanged)
  ///   ├─ A.selectDependencies(prev) == A.selectDependencies(new) → no rebuild
  ///   └─ return withUpdatedChildren (A with newB) ✓
  /// ```
  Self currentOrNewFrom({
    required ReducerViewModelInputs<BlocInputs, UIInputs> newInputs,
    required ReducerViewModelInputs<BlocInputs, UIInputs> previousInputs,
  }) {
    if (newInputs == previousInputs) return this as Self;

    /// Step 1: Resolve children bottom-up
    /// This creates a new instance if anything in the child-tree changed
    final selfWithUpdatedChildren = updateChildren(previousInputs: previousInputs, newInputs: newInputs);
    final childrenChanged = identical(this, selfWithUpdatedChildren) == false;

    /// Step 2: Check own fields via selectDependencies comparison
    final newDependencies = selectDependencies(newInputs, selfWithUpdatedChildren);
    // `this` is always a Self by construction — the F-bounded type param guarantees it
    // ignore: avoid_as
    final selfNeedsRebuild = selectDependencies(previousInputs, this as Self) != newDependencies;

    switch ((selfNeedsRebuild, childrenChanged)) {
      /// Nothing changed
      // ignore: avoid_as
      case (false, false):
        return this as Self;

      /// only children changed ➔ the children-updated instance is already correct
      case (false, true):
        return selfWithUpdatedChildren;

      /// Our own values need to change
      ///
      /// Regardless if childrenChanged or not, `selfWithUpdatedChildren`
      /// has the correct instances of all children.
      /// By calling `rebuildSelf` on this instance, `this` called from inside
      /// `rebuildSelf` always contains the correct children instances
      case (true, _):
        final newSelf = selfWithUpdatedChildren.rebuildSelf(dependencies: newDependencies);
        log("ReducerVMState => ${newSelf.runtimeType} built");
        return newSelf;
    }
  }
}
