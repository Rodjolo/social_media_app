import 'package:flutter/material.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';

class ChatDisabledPage extends StatelessWidget {
  const ChatDisabledPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Chats Disabled'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chat is temporarily disabled while the app is being migrated away from Firebase and Supabase.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
