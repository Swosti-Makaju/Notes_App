import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() => runApp(const NotesApp());

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Notes',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xEF3C3C3F)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xF6EEF0FF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xEF3C3C3F),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xEF3C3C3F),
            foregroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xEF3C3C3F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
        ),
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  String? _selectedFolder; // null = All Notes

  void _selectFolder(String? folder) {
    setState(() => _selectedFolder = folder);
    Navigator.pop(context); // close drawer
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      selectedFolder: _selectedFolder,
      onFolderChanged: (f) => setState(() => _selectedFolder = f),
    );
  }
}