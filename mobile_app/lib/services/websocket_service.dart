import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/connection_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  ConnectionConfig? _currentConnection;
  String? _authToken;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messageStream => 
      _messageController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;
  ConnectionConfig? get currentConnection => _currentConnection;

  Future<bool> connect(ConnectionConfig config) async {
    try {
      disconnect();

      // Create WebSocket connection
      final wsUrl = config.serverUrl.replaceFirst('http', 'ws') + '/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _messageController = StreamController<Map<String, dynamic>>.broadcast();

      // Listen to incoming messages
      _channel!.stream.listen(
        (data) {
          print('📨 WebSocketService: Raw data received: $data');
          try {
            final message = jsonDecode(data) as Map<String, dynamic>;
            print('🎯 WebSocketService: Parsed JSON: $message');
            _handleIncomingMessage(message);
          } catch (e) {
            print('❌ WebSocketService: Error parsing WebSocket message: $e');
            print('📄 WebSocketService: Raw data that failed: $data');
          }
        },
        onError: (error) {
          print('💥 WebSocketService: WebSocket error: $error');
          _handleConnectionError(error);
        },
        onDone: () {
          print('🔌 WebSocketService: WebSocket connection closed');
          _handleDisconnection();
        },
      );

      // Authenticate
      final authSuccess = await _authenticate(config.username, config.password);
      if (authSuccess) {
        _currentConnection = config.copyWith(isConnected: true);
        _isConnected = true;
        return true;
      } else {
        disconnect();
        return false;
      }
    } catch (e) {
      print('Connection failed: $e');
      disconnect();
      return false;
    }
  }

  Future<bool> _authenticate(String username, String password) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;

    // Listen for auth response
    subscription = _messageController!.stream.listen((message) {
      print('Auth response received: $message'); // Debug log
      
      if (message['type'] == 'auth-success') {
        _authToken = message['token'];
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(true);
        }
      } else if (message['type'] == 'error' && !completer.isCompleted) {
        print('Auth error: ${message['message']}'); // Debug log
        subscription.cancel();
        completer.complete(false);
      }
    });

    // Wait a bit for WebSocket to be ready
    await Future.delayed(const Duration(milliseconds: 100));

    // Send auth request
    print('Sending auth request for user: $username'); // Debug log
    _sendMessage({
      'type': 'auth',
      'username': username,
      'password': password,
    });

    // Wait for response with timeout
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Auth timeout: $e'); // Debug log
      subscription.cancel();
      return false;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    print('🔍 WebSocketService: Raw message received: $message');
    
    // Add timestamp if not present
    message['receivedAt'] = DateTime.now().toIso8601String();
    
    print('🔄 WebSocketService: Forwarding message to AppState: $message');
    
    // Forward to listeners
    _messageController?.add(message);
    
    print('✅ WebSocketService: Message forwarded successfully');
  }

  void _handleConnectionError(dynamic error) {
    _messageController?.add({
      'type': 'error',
      'message': 'Connection error: $error',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _handleDisconnection() {
    _isConnected = false;
    _currentConnection = _currentConnection?.copyWith(isConnected: false);
    _messageController?.add({
      'type': 'system',
      'message': 'Disconnected from server',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendCommand(String command) async {
    print('📤 WebSocketService: Sending command: "$command"');
    
    if (!_isConnected || _channel == null) {
      print('❌ WebSocketService: Cannot send command - not connected');
      throw Exception('Not connected to server');
    }

    final message = {
      'type': 'command',
      'command': command,
    };
    
    print('📋 WebSocketService: Command message: $message');
    _sendMessage(message);
  }

  Future<void> startClaudeSession() async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }

    _sendMessage({
      'type': 'claude-start',
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) return;
    
    try {
      final jsonString = jsonEncode(message);
      _channel!.sink.add(jsonString);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void sendPing() {
    _sendMessage({
      'type': 'ping',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _messageController?.close();
    
    _channel = null;
    _messageController = null;
    _authToken = null;
    _isConnected = false;
    _currentConnection = _currentConnection?.copyWith(isConnected: false);
  }

  // Health check
  Future<bool> checkHealth(String serverUrl) async {
    try {
      final response = await Future.delayed(
        const Duration(seconds: 5),
        () => throw TimeoutException('Health check timeout'),
      );
      return false; // Would implement actual HTTP health check
    } catch (e) {
      return false;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}