import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:admob_flutter/admob_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  Admob.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: Color(0xFF1A1A2E),
        primaryColor: Color(0xFF6C5DD3),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF6C5DD3),
          secondary: Color(0xFF00C897),
          surface: Color(0xFF25273D),
        ),
        textTheme: TextTheme(
          bodyText1: TextStyle(color: Color(0xFFF1F1F1)),
          bodyText2: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return HomeScreen();
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
          },
          child: Text("Sign in with Google"),
          style: ElevatedButton.styleFrom(primary: Color(0xFF6C5DD3)),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DeployScreen(),
    LogsScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Color(0xFF25273D),
        selectedItemColor: Color(0xFF6C5DD3),
        unselectedItemColor: Color(0xFF9CA3AF),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Deploy'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}

class DeployScreen extends StatefulWidget {
  @override
  _DeployScreenState createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  final _repoController = TextEditingController();
  String? _botId;

  void _showAdAndDeploy() async {
    final ad = AdmobRewarded(
      adUnitId: 'your-admob-ad-unit-id',
      listener: (event, args) async {
        if (event == AdmobAdEvent.rewarded) {
          final response = await http.post(
            Uri.parse('https://your-railway-url/bots/deploy'),
            headers: {
              'Authorization': 'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}',
            },
            body: jsonEncode({'repo_url': _repoController.text}),
          );
          if (response.statusCode == 200) {
            setState(() {
              _botId = jsonDecode(response.body)['bot_id'];
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bot deployed!')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(response.body)['detail'])));
          }
        }
      },
    );
    ad.load();
    ad.show();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _repoController,
            decoration: InputDecoration(
              labelText: 'GitHub Repo URL',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Color(0xFF25273D),
            ),
            style: TextStyle(color: Color(0xFFF1F1F1)),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAdAndDeploy,
            child: Text('Deploy Bot'),
            style: ElevatedButton.styleFrom(primary: Color(0xFF6C5DD3)),
          ),
        ],
      ),
    );
  }
}

class LogsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final channel = WebSocketChannel.connect(Uri.parse('wss://your-railway-url/ws/logs/your-bot-id'));
    return StreamBuilder(
      stream: channel.stream,
      builder: (context, snapshot) {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            snapshot.hasData ? snapshot.data.toString() : 'Waiting for logs...',
            style: TextStyle(color: Color(0xFFF1F1F1)),
          ),
        );
      },
    );
  }
}

class StatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: http.get(
        Uri.parse('https://your-railway-url/bots/your-bot-id/stats'),
        headers: {'Authorization': 'Bearer ${FirebaseAuth.instance.currentUser!.getIdToken()}'},
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stats = jsonDecode(snapshot.data!.body);
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('CPU: ${stats['cpu_usage']}', style: TextStyle(color: Color(0xFFF1F1F1))),
                Text('Memory: ${stats['memory_usage']}', style: TextStyle(color: Color(0xFFF1F1F1))),
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