class ConnectionConfig {
  final String serverUrl;
  final String username;
  final String password;
  final bool isConnected;

  ConnectionConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.isConnected = false,
  });

  ConnectionConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    bool? isConnected,
  }) {
    return ConnectionConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'isConnected': isConnected,
    };
  }

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      serverUrl: json['serverUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      isConnected: json['isConnected'] ?? false,
    );
  }
}