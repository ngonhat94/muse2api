// Disconnected responsive fixture: no credentials, repositories or Muse calls.
// flutter build web -t tool/generation_preview.dart --output build/generation_preview
import 'package:flutter/material.dart';
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/core/presentation/generation_workspace.dart';

void main() {
  const scale = 2.0;
  runApp(
    MaterialApp(
      theme: StudioTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(scale)),
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Xem trước video',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    const GenerationPreview(
                      video: true,
                      busy: true,
                      status: 'Muse đang tạo video · 25%',
                    ),
                    const SizedBox(height: 24),
                    const GenerationPreview(video: true, busy: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
