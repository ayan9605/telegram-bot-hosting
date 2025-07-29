import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LogsScreen extends StatelessWidget {
  final String botId = 'your-bot-id'; // Replace with dynamic bot ID from DeployScreen

  @override
  Widget build(BuildContext context) {
    final channel = WebSocketChannel.connect(Uri.parse('wss://your-railway-url/bots/logs/$botId'));
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            child: Text(
              snapshot.hasData ? snapshot.data.toString() : 'Waiting for logs...',
              style: TextStyle(color: Color(0xFFF1F1F1)),
            ),
          );
        },
      ),
    );
  }
}