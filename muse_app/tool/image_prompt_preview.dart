// Disconnected visual harness. Never initializes Muse or reads saved credentials.
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/features/image_prompt/data/image_prompt_repository_impl.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_cubit.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_page.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: StudioTheme.dark,
    home: BlocProvider(
      create: (_) =>
          ImagePromptCubit(ImagePromptRepositoryImpl(http.Client.new)),
      child: ImagePromptPage(
        pickImage: () async => XFile.fromData(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKklEQVR4nO3NQQkAAAgEsAtuGjMawBQ+hMH+y3SdikAgEAgEAoFAIPgSLF13SHk5j18ZAAAAAElFTkSuQmCC',
          ),
          name: 'synthetic-peach.png',
        ),
      ),
    ),
  ),
);
