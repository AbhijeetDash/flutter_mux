part of '../mux.dart';

/// A request whose response of type [T] is cached under [key].
///
/// Extend it with a sealed hierarchy so the service handler can switch
/// exhaustively:
///
/// ```dart
/// sealed class AppRequest<T> extends Request<T> {
///   const AppRequest();
/// }
///
/// final class FetchUsers extends AppRequest<UserPage> {
///   const FetchUsers(this.filter);
///   final Filter filter;
///
///   @override
///   Object get key => (UsersList, filter);
/// }
/// ```
abstract base class Request<T> {
  const Request();

  /// Cache identity, usually a record such as `(UsersList, filter)`.
  ///
  /// Every field must implement `==` and `hashCode`. Requests that share a key
  /// share one cache entry and must declare the same [T].
  Object get key;

  /// Whether the entry survives after its last subscriber releases it.
  bool get keepAlive => false;

  /// Runs [body] with this request's runtime [T], so states built from a
  /// loosely typed reference still carry the exact type.
  S _capture<S>(S Function<X>() body) => body<T>();
}
