import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ssh_connection.dart';
import '../providers/app_state.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: '');
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Claude-Code Mobile'),
        backgroundColor: const Color(0xFF2D2D30),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  Icon(
                    Icons.cloud_outlined,
                    size: 80,
                    color: Colors.blue[300],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    'Connect to Remote Server',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Enter your SSH connection details to start coding with Claude-Code',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  _buildTextField(
                    controller: _hostController,
                    label: 'Host/IP Address',
                    icon: Icons.dns,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter host address';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _portController,
                    label: 'Port',
                    icon: Icons.settings_ethernet,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter port number';
                      }
                      final port = int.tryParse(value!);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Please enter valid port (1-65535)';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter username';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: appState.isConnecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: appState.isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Make sure Docker is installed on your server and your Anthropic API key is configured.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF2D2D30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    final connection = SSHConnection(
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final appState = Provider.of<AppState>(context, listen: false);
    final success = await appState.connectToServer(connection);

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/chat');
    }
  }
}