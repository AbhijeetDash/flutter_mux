import 'package:flutter/material.dart';
import 'package:flutter_mux/flutter_mux.dart';

import 'models.dart';
import 'requests.dart';
import 'users_service.dart';

@WithService(UsersService)
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.initialFilter});

  final UserFilter initialFilter;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late var _filter = widget.initialFilter;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => context.send(FetchUsers(_filter));

  void _loadMore() => context.send(LoadMoreUsers(_filter));

  void _select(UserFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _refresh();
  }

  void _openAdmins() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const UsersScreen(initialFilter: UserFilter.admins),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users · ${_filter.label}'),
        actions: [
          IconButton(
            tooltip: 'Open admins',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openAdmins,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final filter in UserFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: filter == _filter,
                    onSelected: (_) => _select(filter),
                  ),
              ],
            ),
          ),
          Expanded(
            child: MuxBuilder<UserPage>(
              request: FetchUsers(_filter),
              builder: (context, state) => switch (state) {
                Idle() || Loading(previous: null) => const Center(
                  key: Key('initial-load'),
                  child: CircularProgressIndicator(),
                ),
                Loading(:final UserPage previous) => _UserList(
                  page: previous,
                  busy: true,
                  onRefresh: _refresh,
                  onLoadMore: _loadMore,
                ),
                Data(:final value) => _UserList(
                  page: value,
                  onRefresh: _refresh,
                  onLoadMore: _loadMore,
                ),
                Failure(previous: null, :final error) => Center(
                  child: TextButton(
                    onPressed: _refresh,
                    child: Text('Failed: $error. Retry'),
                  ),
                ),
                Failure(:final UserPage previous, :final error) => _UserList(
                  page: previous,
                  error: error,
                  onRefresh: _refresh,
                  onLoadMore: _loadMore,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.page,
    required this.onRefresh,
    required this.onLoadMore,
    this.busy = false,
    this.error,
  });

  final UserPage page;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final bool busy;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 4,
          child: busy ? const LinearProgressIndicator() : null,
        ),
        if (error != null)
          ListTile(
            tileColor: Theme.of(context).colorScheme.errorContainer,
            title: Text('Refresh failed: $error'),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 300) onLoadMore();
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: page.users.length + 1,
                itemBuilder: (context, index) {
                  if (index == page.users.length) return _footer();
                  final user = page.users[index];
                  return ListTile(
                    title: Text(user.name),
                    subtitle: Text(
                      [
                        if (user.isAdmin) 'admin',
                        user.isActive ? 'active' : 'inactive',
                      ].join(' · '),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: Text(
        '${page.users.length} users · fetch #${page.fetch}'
        '${page.nextCursor == null ? '' : ' · scroll for more'}',
      ),
    ),
  );
}
