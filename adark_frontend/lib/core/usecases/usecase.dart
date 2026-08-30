import 'package:equatable/equatable.dart';

/// Base class for all Use Cases in Clean Architecture.
///
/// Type parameters:
/// - [Type] - The return type of the use case
/// - [Params] - The parameters needed (extends Equatable)
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Used when a use case doesn't need any parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
