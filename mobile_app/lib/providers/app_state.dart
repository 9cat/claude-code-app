import 'package:flutter/foundation.dart';
import '../models/connection_config.dart';
import '../models/chat_message.dart';
import '../services/websocket_service.dart';
import '../services/voice_service.dart';

class AppState extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final VoiceService _voiceService = VoiceService();
  
  final List<ChatMessage> _messages = [];
  ConnectionConfig? _currentConnection;
  bool _isConnecting = false;
  bool _isVoiceEnabled = false;
  String _currentInput = '';

  List<ChatMessage> get messages => _messages;
  ConnectionConfig? get currentConnection => _currentConnection;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _wsService.isConnected;
  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isListening => _voiceService.isListening;
  String get currentInput => _currentInput;

  AppState() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _isVoiceEnabled = await _voiceService.initialize();
    
    print('🔧 AppState: Setting up WebSocket message stream listener...');
    _wsService.messageStream.listen(
      (message) {
        print('🎯 AppState: Stream listener received message: $message');
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        print('❌ AppState: Stream listener error: $error');
      },
      onDone: () {
        print('✅ AppState: Stream listener done');
      },
    );
    
    notifyListeners();
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    print('📨 AppState: Received WebSocket message: $message');
    
    final type = message['type'] as String?;
    final content = message['message'] ?? message['data'] ?? '';
    
    print('🔍 AppState: Message type: $type, content: "$content"');
    print('🔍 AppState: Current messages count: ${_messages.length}');
    
    MessageType messageType;
    switch (type) {
      case 'claude-output':
        messageType = MessageType.assistant;
        break;
      case 'user-input':
        messageType = MessageType.user;
        break;
      case 'output':
        messageType = MessageType.system;
        break;
      case 'system':
      case 'auth-success':
      case 'claude-started':
      case 'command-complete':
      case 'claude-session-ended':
        messageType = MessageType.system;
        break;
      case 'error':
        messageType = MessageType.error;
        break;
      default:
        messageType = MessageType.system;
    }

    // Don't add empty messages (but log them)
    if (content.toString().trim().isEmpty) {
      print('⚠️ AppState: Skipping empty message of type: $type');
      return;
    }

    print('✅ AppState: Adding message to UI: type=$messageType, content="${content.toString()}"');
    print('📝 AppState: Before adding - messages count: ${_messages.length}');
    
    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.toString(),
      type: messageType,
      timestamp: DateTime.now(),
    ));
    
    print('📝 AppState: After adding - messages count: ${_messages.length}');
  }

  Future<bool> connectToServer(ConnectionConfig connection) async {
    _isConnecting = true;
    notifyListeners();

    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Connecting to ${connection.serverUrl}...',
      type: MessageType.system,
      timestamp: DateTime.now(),
    ));

    final success = await _wsService.connect(connection);
    
    if (success) {
      _currentConnection = connection;
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Connected successfully! Ready to interact with Claude-Code.',
        type: MessageType.system,
        timestamp: DateTime.now(),
      ));
    } else {
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Connection failed. Please check your server URL and credentials.',
        type: MessageType.error,
        timestamp: DateTime.now(),
      ));
    }

    _isConnecting = false;
    notifyListeners();
    return success;
  }

  void disconnect() {
    _wsService.disconnect();
    _currentConnection = null;
    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Disconnected from server.',
      type: MessageType.system,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void addMessage(ChatMessage message) {
    print('💬 AppState: addMessage called with: ${message.content} (type: ${message.type})');
    _messages.add(message);
    print('💬 AppState: Messages list now has ${_messages.length} items');
    notifyListeners();
    print('💬 AppState: notifyListeners called');
  }

  Future<void> sendCommand(String command) async {
    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: command,
      type: MessageType.user,
      timestamp: DateTime.now(),
    ));

    try {
      await _wsService.sendCommand(command);
    } catch (e) {
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error sending command: $e',
        type: MessageType.error,
        timestamp: DateTime.now(),
      ));
    }
    
    _currentInput = '';
    notifyListeners();
  }

  Future<void> startClaudeSession() async {
    try {
      await _wsService.startClaudeSession();
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Starting Claude interactive session...',
        type: MessageType.system,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error starting Claude session: $e',
        type: MessageType.error,
        timestamp: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  void updateCurrentInput(String input) {
    _currentInput = input;
    notifyListeners();
  }

  Future<void> startVoiceInput() async {
    if (!_isVoiceEnabled) return;

    await _voiceService.startListening(
      onResult: (text) {
        updateCurrentInput(text);
      },
    );
    notifyListeners();
  }

  Future<void> stopVoiceInput() async {
    await _voiceService.stopListening();
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}