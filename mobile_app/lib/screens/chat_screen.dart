import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../providers/app_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.terminal, color: Colors.green[300], size: 20),
            const SizedBox(width: 8),
            const Text('Claude-Code CLI', style: TextStyle(fontFamily: 'monospace')),
          ],
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              return IconButton(
                icon: Icon(
                  appState.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: appState.isConnected ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  if (appState.isConnected) {
                    _showDisconnectDialog(context, appState);
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              Provider.of<AppState>(context, listen: false).clearMessages();
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: appState.messages.length,
                  itemBuilder: (context, index) {
                    final message = appState.messages[index];
                    _scrollToBottom();
                    return _buildMessageBubble(message);
                  },
                ),
              ),
              _buildInputArea(appState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Terminal-style colors
    Color promptColor = Colors.blue[300]!;
    Color outputColor = Colors.green[300]!;
    Color systemColor = Colors.yellow[300]!;
    Color errorColor = Colors.red[300]!;
    
    String prefix;
    Color textColor;
    
    switch (message.type) {
      case MessageType.user:
        prefix = '➤ ';
        textColor = promptColor;
        break;
      case MessageType.assistant:
        prefix = '';
        textColor = outputColor;
        break;
      case MessageType.system:
        prefix = '[SYSTEM] ';
        textColor = systemColor;
        break;
      case MessageType.error:
        prefix = '[ERROR] ';
        textColor = errorColor;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal-style timestamp
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Message content
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: prefix,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: message.content,
                    style: TextStyle(
                      color: message.type == MessageType.assistant ? outputColor : textColor,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D30),
        border: Border(
          top: BorderSide(color: Color(0xFF3E3E42), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              maxLines: null,
              decoration: InputDecoration(
                prefixText: appState.isConnected ? '➤ ' : '✗ ',
                prefixStyle: TextStyle(
                  color: appState.isConnected ? Colors.blue[300] : Colors.red[300],
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                hintText: appState.isConnected
                    ? 'Enter your command...'
                    : 'Not connected to server',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.blue[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              enabled: appState.isConnected,
              onChanged: (value) => appState.updateCurrentInput(value),
              onSubmitted: appState.isConnected ? (value) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          
          if (appState.isVoiceEnabled)
            IconButton(
              onPressed: appState.isConnected
                  ? (appState.isListening ? appState.stopVoiceInput : appState.startVoiceInput)
                  : null,
              icon: Icon(
                appState.isListening ? Icons.mic : Icons.mic_none,
                color: appState.isListening ? Colors.red : Colors.grey[400],
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: const CircleBorder(),
              ),
            ),
          
          IconButton(
            onPressed: appState.isConnected && _messageController.text.trim().isNotEmpty
                ? _sendMessage
                : null,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);
    appState.sendCommand(message);
    _messageController.clear();
  }

  String _getMessageTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.user:
        return 'YOU';
      case MessageType.assistant:
        return 'CLAUDE';
      case MessageType.system:
        return 'SYSTEM';
      case MessageType.error:
        return 'ERROR';
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _showDisconnectDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        title: const Text('Disconnect', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disconnect from the server?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              appState.disconnect();
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/connection');
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}