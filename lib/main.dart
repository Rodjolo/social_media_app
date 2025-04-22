import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:socail_media_app/config/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://brpdfvvhcltheskyxzms.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJycGRmdnZoY2x0aGVza3l4em1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA0MjE1MjIsImV4cCI6MjA1NTk5NzUyMn0.5ifRZhYBolSc6ml4SCqrcY5rpD8UvSHjxcexA2HaqDg',
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp());
}

