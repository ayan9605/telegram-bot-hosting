import 'package:flutter/material.dart';
import 'package:telegram_bot_hosting/services/api_service.dart';

class StatsScreen extends StatelessWidget {
  final String botId = 'your-bot-id'; // Replace with dynamic bot ID

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ApiService.getStats(botId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stats = snapshot.data as Map<String, dynamic>;
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('CPU Usage: ${stats['cpu_usage']}', style: TextStyle(color: Color(0xFFF1F1F1))),
                Text('Memory Usage: ${stats['memory_usage']}', style: TextStyle(color: Color(0xFFF1F1F1))),
                Text('Storage: ${stats['storage']}', style: TextStyle(color: Color(0xFFF1F1F1))),
              ],
            ),
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}