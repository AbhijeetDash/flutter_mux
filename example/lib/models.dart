final class User {
  const User({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isAdmin,
  });

  final int id;
  final String name;
  final bool isActive;
  final bool isAdmin;
}

final class UserPage {
  const UserPage(this.users, {this.nextCursor, required this.fetch});

  final List<User> users;
  final int? nextCursor;

  /// Which backend call produced this page; shows that the latest one wins.
  final int fetch;
}

enum UserFilter {
  all('All'),
  active('Active'),
  admins('Admins');

  const UserFilter(this.label);

  final String label;

  bool matches(User user) => switch (this) {
    all => true,
    active => user.isActive,
    admins => user.isAdmin,
  };
}
