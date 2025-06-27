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
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Claude-Code Terminal'),
        backgroundColor: const Color(0xFF2D2D30),
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
    Color bubbleColor;
    Color textColor = Colors.white;
    IconData? icon;

    switch (message.type) {
      case MessageType.user:
        bubbleColor = Colors.blue[600]!;
        icon = Icons.person;
        break;
      case MessageType.assistant:
        bubbleColor = const Color(0xFF2D2D30);
        icon = Icons.smart_toy;
        break;
      case MessageType.system:
        bubbleColor = Colors.green[700]!;
        icon = Icons.terminal;
        break;
      case MessageType.error:
        bubbleColor = Colors.red[700]!;
        icon = Icons.error;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 16,
              color: textColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: bubbleColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMessageTypeLabel(message.type),
                    style: TextStyle(
                      color: bubbleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (message.type == MessageType.assistant)
                    MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: textColor),
                        code: TextStyle(
                          backgroundColor: Colors.grey[800],
                          color: Colors.green[300],
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: message.type == MessageType.system ? 'monospace' : null,
                        fontSize: message.type == MessageType.system ? 12 : 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
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
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              decoration: InputDecoration(
                hintText: appState.isConnected
                    ? 'Type your command or question...'
                    : 'Not connected to server',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
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