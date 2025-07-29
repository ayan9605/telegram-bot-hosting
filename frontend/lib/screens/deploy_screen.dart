import 'package:flutter/material.dart';
import 'package:admob_flutter/admob_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:telegram_bot_hosting/services/api_service.dart';

class DeployScreen extends StatefulWidget {
  @override
  _DeployScreenState createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  final _repoController = TextEditingController();
  String? _botId;
  String? _botFilePath;
  String? _reqFilePath;

  void _showAdAndDeploy() async {
    final ad = AdmobRewarded(
      adUnitId: 'your-admob-ad-unit-id',
      listener: (event, args) async {
        if (event == AdmobAdEvent.rewarded) {
          try {
            Map<String, dynamic> response;
            if (_repoController.text.isNotEmpty) {
              response = await ApiService.deployBot(_repoController.text);
            } else if (_botFilePath != null && _reqFilePath != null) {
              response = await ApiService.uploadFiles(_botId!, _botFilePath!, _reqFilePath!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provide repo URL or files')));
              return;
            }
            setState(() {
              _botId = response['bot_id'];
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bot deployed!')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
    );
    await ad.load();
    ad.show();
  }

  void _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.length == 2) {
      setState(() {
        _botFilePath = result.files.first.path;
        _reqFilePath = result.files.last.path;
        _botId = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _repoController,
            decoration: InputDecoration(labelText: 'GitHub Repo URL'),
            style: TextStyle(color: Color(0xFFF1F1F1)),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _pickFiles,
            child: Text('Upload bot.py & requirements.txt'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAdAndDeploy,
            child: Text('Deploy Bot'),
          ),
          if (_botId != null) ...[
            SizedBox(height: 16),
            Text('Bot ID: $_botId', style: TextStyle(color: Color(0xFFF1F1F1))),
            ElevatedButton(
              onPressed: () async {
                await ApiService.stopBot(_botId!);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bot stopped')));
              },
              child: Text('Stop Bot'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService.restartBot(_botId!);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bot restarted')));
              },
              child: Text('Restart Bot'),
            ),
          ],
        ],
      ),
    );
  }
}