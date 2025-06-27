import 'package:flutter/foundation.dart';
import '../models/ssh_connection.dart';
import '../models/chat_message.dart';
import '../services/ssh_service.dart';
import '../services/voice_service.dart';

class AppState extends ChangeNotifier {
  final SSHService _sshService = SSHService();
  final VoiceService _voiceService = VoiceService();
  
  final List<ChatMessage> _messages = [];
  SSHConnection? _currentConnection;
  bool _isConnecting = false;
  bool _isVoiceEnabled = false;
  String _currentInput = '';

  List<ChatMessage> get messages => _messages;
  SSHConnection? get currentConnection => _currentConnection;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _sshService.isConnected;
  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isListening => _voiceService.isListening;
  String get currentInput => _currentInput;

  AppState() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _isVoiceEnabled = await _voiceService.initialize();
    
    _sshService.outputStream.listen((output) {
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: output,
        type: MessageType.system,
        timestamp: DateTime.now(),
      ));
    });
    
    notifyListeners();
  }

  Future<bool> connectToServer(SSHConnection connection) async {
    _isConnecting = true;
    notifyListeners();

    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Connecting to ${connection.host}:${connection.port}...',
      type: MessageType.system,
      timestamp: DateTime.now(),
    ));

    final success = await _sshService.connect(connection);
    
    if (success) {
      _currentConnection = connection;
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Connected successfully! Starting Claude-Code environment...',
        type: MessageType.system,
        timestamp: DateTime.now(),
      ));
      
      await _sshService.startClaudeCodeSession();
    } else {
      addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Connection failed. Please check your credentials.',
        type: MessageType.error,
        timestamp: DateTime.now(),
      ));
    }

    _isConnecting = false;
    notifyListeners();
    return success;
  }

  void disconnect() {
    _sshService.disconnect();
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
    _messages.add(message);
    notifyListeners();
  }

  Future<void> sendCommand(String command) async {
    addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: command,
      type: MessageType.user,
      timestamp: DateTime.now(),
    ));

    await _sshService.executeCommand(command);
    _currentInput = '';
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