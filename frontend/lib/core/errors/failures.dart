/// Base class for all failures/errors in Clean Architecture.
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Server-related failures (API, network issues)
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

/// Cache-related failures (local storage)
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error occurred']);
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}