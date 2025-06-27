import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'providers/app_state.dart';
import 'screens/connection_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  runApp(const ClaudeCodeApp());
}

class ClaudeCodeApp extends StatelessWidget {
  const ClaudeCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Claude-Code Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        initialRoute: '/connection',
        routes: {
          '/connection': (context) => const ConnectionScreen(),
          '/chat': (context) => const ChatScreen(),
        },
      ),
    );
  }
}