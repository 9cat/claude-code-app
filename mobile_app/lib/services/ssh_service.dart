import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_connection.dart';

class SSHService {
  static final SSHService _instance = SSHService._internal();
  factory SSHService() => _instance;
  SSHService._internal();

  SSHClient? _client;
  SSHSession? _session;
  StreamController<String>? _outputController;
  SSHConnection? _currentConnection;

  Stream<String> get outputStream => _outputController?.stream ?? const Stream.empty();
  bool get isConnected => _client != null && _currentConnection?.isConnected == true;

  Future<bool> connect(SSHConnection connection) async {
    try {
      disconnect();

      _client = SSHClient(
        await SSHSocket.connect(connection.host, connection.port),
        username: connection.username,
        onPasswordRequest: () => connection.password ?? '',
      );

      _currentConnection = connection.copyWith(isConnected: true);
      _outputController = StreamController<String>.broadcast();

      return true;
    } catch (e) {
      print('SSH connection failed: $e');
      disconnect();
      return false;
    }
  }

  Future<void> startClaudeCodeSession() async {
    if (_client == null) return;

    try {
      _session = await _client!.shell();
      
      _session!.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen((data) {
        _outputController?.add(data);
      });

      _session!.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen((data) {
        _outputController?.add('ERROR: $data');
      });

      await executeCommand('docker run -d --name claude-code-container --privileged -v /var/run/docker.sock:/var/run/docker.sock -p 63980:63980 -e ANTHROPIC_API_KEY=\$ANTHROPIC_API_KEY claude-code:latest');
      
      await Future.delayed(const Duration(seconds: 5));
      
      await executeCommand('docker exec -it claude-code-container bash -c "claude"');
    } catch (e) {
      _outputController?.add('Failed to start Claude-Code session: $e');
    }
  }

  Future<void> executeCommand(String command) async {
    if (_session == null) return;

    try {
      _session!.stdin.add(utf8.encode('$command\n'));
    } catch (e) {
      _outputController?.add('Command execution failed: $e');
    }
  }

  void disconnect() {
    _session?.close();
    _client?.close();
    _outputController?.close();
    
    _client = null;
    _session = null;
    _outputController = null;
    _currentConnection = _currentConnection?.copyWith(isConnected: false);
  }

  SSHConnection? get currentConnection => _currentConnection;
}