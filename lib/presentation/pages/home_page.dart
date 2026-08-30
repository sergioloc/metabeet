import 'package:flutter/material.dart';

import '../widgets/app_toolbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppToolbar(appName: 'Metabeet'),
      body: Center(
        child: Text(
          'Importa un archivo de audio para editar su metadatos',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}