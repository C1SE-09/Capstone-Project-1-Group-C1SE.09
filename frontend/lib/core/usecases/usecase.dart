import 'package:equatable/equatable.dart';

/// Base class for all Use Cases in Clean Architecture.
///
/// Type parameters:
/// - [T] - The return type of the use case
/// - [Params] - The parameters needed (extends Equatable)
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Used when a use case doesn't need any parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
