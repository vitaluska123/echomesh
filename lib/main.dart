import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

import 'app/echomesh_app.dart';
import 'bridge_generated.dart/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop (Linux/Windows): load from `rust/target/{debug|release}/`
  // Android: load from APK/system loader (ioDirectory must be null).
  final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;

  final String? ioDirectory = isAndroid
      ? null
      : (kReleaseMode ? 'rust/target/release/' : 'rust/target/debug/');

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
