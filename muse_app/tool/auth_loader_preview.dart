// Disconnected visual fixture; does not read or validate real credentials.
import 'package:flutter/material.dart';
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/features/connection/presentation/widgets/shiba_loading.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: StudioTheme.dark,
    home: const ShibaLoadingPage(),
  ),
);
