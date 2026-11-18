import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/extension_download.dart';

class ExtensionDownloadState {
  const ExtensionDownloadState({this.busy = false, this.bytes, this.message});
  final bool busy;
  final Uint8List? bytes;
  final String? message;
}

class ExtensionDownloadCubit extends Cubit<ExtensionDownloadState> {
  ExtensionDownloadCubit(this.repository)
    : super(const ExtensionDownloadState());
  final ExtensionDownload repository;
  int _generation = 0;
  void reset() {
    ++_generation;
    if (!isClosed) emit(const ExtensionDownloadState());
  }

  Future<void> load(
    ServerConnection connection,
    bool Function() current,
  ) async {
    if (isClosed || state.busy || !current()) return;
    final generation = ++_generation;
    bool valid() => !isClosed && generation == _generation && current();
    emit(const ExtensionDownloadState(busy: true));
    try {
      final bytes = await repository.fetch(connection);
      if (valid()) emit(ExtensionDownloadState(bytes: bytes));
    } catch (error) {
      if (valid()) {
        emit(
          ExtensionDownloadState(
            message: error is AppFailure
                ? error.message
                : 'Không tải được extension. Hãy thử lại.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
