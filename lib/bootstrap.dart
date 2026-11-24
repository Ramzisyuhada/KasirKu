import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

enum Env { 
  dev, 
  prod, 
}

Future<void> bootstrap (Env env) async {
  WidgetsFlutterBinding.ensureInitialized();
 
 await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const  String.fromEnvironment('SUPABASE_ANON_KEY'), 
  ); // Change this to Env.prod for production

 runApp(ProviderScope(child: App(env: env)));
}