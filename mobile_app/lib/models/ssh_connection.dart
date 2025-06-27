class SSHConnection {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final bool isConnected;

  SSHConnection({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.isConnected = false,
  });

  SSHConnection copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    bool? isConnected,
  }) {
    return SSHConnection(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'isConnected': isConnected,
    };
  }

  factory SSHConnection.fromJson(Map<String, dynamic> json) {
    return SSHConnection(
      host: json['host'] ?? '',
      port: json['port'] ?? 22,
      username: json['username'] ?? '',
      password: json['password'],
      privateKey: json['privateKey'],
      isConnected: json['isConnected'] ?? false,
    );
  }
}