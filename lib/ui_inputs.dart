import 'package:equatable/equatable.dart';

// Enforcing that the class extends Equatable is necessary
// to ensure the comparison logic in the cubit works correctly
abstract class ReducerVMUIInputs extends Equatable {
  const ReducerVMUIInputs();
}
