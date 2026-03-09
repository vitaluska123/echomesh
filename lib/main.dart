import 'package:flutter/material.dart';
import 'bridge_generated.dart/frb_generated.dart';  // ← обязательно этот импорт!
import 'bridge_generated.dart/api.dart';            // для greet

Future<void> main() async {
  await RustLib.init();  // ← это решает проблему "has not been initialized"

  runApp(const EchoMeshApp());
}

class EchoMeshApp extends StatelessWidget {
  const EchoMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoMesh',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoMesh — тест Rust'),
      ),
      body: Center(

        child: ElevatedButton(
          onPressed: () async {
            try {
              final peerId = await generatePeerId();
              print('Мой Peer ID: $peerId');
              // Можно показать в UI через setState или Riverpod/Bloc
            } catch (e) {
              print('Ошибка: $e');
            }
          },
          child: const Text('Сгенерировать Peer ID'),
        )
        ),
      );
  }
}
