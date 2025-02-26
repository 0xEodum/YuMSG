class UserSearchItem {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  const UserSearchItem({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory UserSearchItem.fromJson(Map<String, dynamic> json) {
    return UserSearchItem(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}

class SearchResult {
  final List<UserSearchItem> users;
  final String? nextPageToken;

  const SearchResult({
    required this.users,
    this.nextPageToken,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      users: (json['users'] as List)
          .map((user) => UserSearchItem.fromJson(user))
          .toList(),
      nextPageToken: json['nextPageToken'] as String?,
    );
  }
}