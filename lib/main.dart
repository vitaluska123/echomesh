import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

import 'bridge_generated.dart/api.dart'; // для greet
import 'bridge_generated.dart/frb_generated.dart'; // ← обязательно этот импорт!

Future<void> main() async {
  // Pick correct Rust library location depending on build mode.
  // - Debug/Profile: `cargo build` → `rust/target/debug/`
  // - Release: `cargo build --release` → `rust/target/release/`
  final ioDirectory = kReleaseMode ? 'rust/target/release/' : 'rust/target/debug/';

  final externalLibrary = await loadExternalLibrary(
    ExternalLibraryLoaderConfig(
      stem: 'echomesh',
      ioDirectory: ioDirectory,
      webPrefix: 'pkg/',
    ),
  );

  await RustLib.init(externalLibrary: externalLibrary);

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
