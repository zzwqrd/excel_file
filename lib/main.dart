import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'file_browser_screen.dart';
import 'policy_provider.dart';

void main() {
  runApp(const MyApp());
}

/////
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PolicyProvider(),
      child: MaterialApp(
        title: 'File Labelling App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const FileBrowserScreen(),
      ),
    );
  }
}
