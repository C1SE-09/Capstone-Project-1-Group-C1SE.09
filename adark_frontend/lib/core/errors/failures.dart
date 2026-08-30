/// Base class for all failures/errors in Clean Architecture.
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Server-related failures (API, network issues)
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred']) : super(message);
}

/// Cache-related failures (local storage)
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred']) : super(message);
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection']) : super(message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}
