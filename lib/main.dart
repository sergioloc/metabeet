import 'package:flutter/material.dart';

import 'presentation/pages/home_page.dart';

void main() {
  runApp(const MetabeetApp());
}

class MetabeetApp extends StatelessWidget {
  const MetabeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metabeet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}