import '../../../../app/studio_theme.dart';

import 'package:flutter/foundation.dart';

import '../../../../core/data/library_batch_saver_factory.dart';
import '../../../../core/domain/save_library.dart';
import '../../../../core/domain/save_media.dart';
import '../../domain/usecases/query_library.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/collection_bloc.dart';
import '../../../../core/presentation/list_header.dart';
import '../../../../core/presentation/media_preview.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../../domain/entities/media_name.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../bloc/media_bloc.dart';
import 'storage_usage_panel.dart';
import '../../domain/repositories/storage_repository.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key, this.saver, this.storageRepository});
  final LibrarySaver? saver;
  final StorageRepository? storageRepository;
  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  final Set<String> _selected = {};
  ServerConnection? _selectionConnection;
  bool _confirming = false;
  LibraryType _type = LibraryType.all;
  String _search = '';
  bool _newest = true;
  bool _saving = false;
  bool _cancelSave = false;
  String? _saveProgress;
  List<LibrarySaveEntry> _saveResults = [];
  late final LibrarySaver _saver = widget.saver ?? createLibrarySaver();

  Future<void> _save(ServerConnection connection) async {
    final bloc = context.read<MediaBloc>();
    if (_saving ||
        _confirming ||
        bloc.state.loading ||
        bloc.state.deleting ||
        bloc.state.stale ||
        !bloc.matches(connection)) {
      return;
    }
    if (kIsWeb ||
        ![
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ].contains(defaultTargetPlatform)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu vào thư mục chỉ hỗ trợ macOS, Windows và Linux.'),
        ),
      );
      return;
    }
    final byName = {for (final item in bloc.state.items) item.name: item};
    final sources = _selected
        .map((name) => byName[name]?.protectedUri)
        .whereType<Uri>()
        .map((uri) => MediaSaveSource.remote(connection, uri))
        .toList();
    setState(() {
      _saving = true;
      _cancelSave = false;
      _saveResults = [];
      _saveProgress = 'Đang chọn thư mục…';
    });
    bool current() {
      if (!mounted || _cancelSave) return false;
      final active = context.read<ConnectionBloc>().state.connection;
      return active?.baseUrl == connection.baseUrl &&
          active?.apiKey == connection.apiKey &&
          bloc.matches(connection) &&
          !bloc.state.stale;
    }

    try {
      final results = await _saver.save(
        sources,
        isCurrent: current,
        onProgress: (name, bytes) {
          if (current()) {
            setState(
              () => _saveProgress =
                  '$name · ${(bytes / 1024).toStringAsFixed(0)} KB',
            );
          }
        },
      );
      if (mounted &&
          _selectionConnection?.baseUrl == connection.baseUrl &&
          _selectionConnection?.apiKey == connection.apiKey) {
        setState(() => _saveResults = results);
      }
    } catch (_) {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không lưu được media. Kiểm tra tên tệp, quyền ghi và thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveProgress = null;
        });
      }
    }
  }

  void _changeQuery(VoidCallback change) => setState(() {
    change();
    _selected.clear();
  });

  @override
  void dispose() {
    _cancelSave = true;
    super.dispose();
  }

  Future<void> _delete(ServerConnection connection, List<String> names) async {
    final bloc = context.read<MediaBloc>();
    if (_confirming ||
        bloc.state.deleting ||
        bloc.state.stale ||
        bloc.state.loading ||
        !bloc.matches(connection)) {
      return;
    }
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa media?'),
        content: Text(
          names.length == 1
              ? 'Xóa “${names.single}” khỏi server? Không thể hoàn tác.'
              : 'Xóa ${names.length} tệp đã chọn khỏi server? Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true) return;
    final current = context.read<ConnectionBloc>().state.connection;
    if (current?.baseUrl != connection.baseUrl ||
        current?.apiKey != connection.apiKey ||
        !bloc.matches(connection)) {
      return;
    }
    bloc.add(MediaDeleteRequested(connection, names));
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<MediaBloc, MediaState>(
    builder: (context, state) {
      final connection = context.watch<ConnectionBloc>().state.connection;
      if (_selectionConnection?.baseUrl != connection?.baseUrl ||
          _selectionConnection?.apiKey != connection?.apiKey) {
        _selected.clear();
        _saveResults = [];
        if (_saving) _cancelSave = true;
        _selectionConnection = connection;
      }
      _selected.removeWhere(
        (name) => !state.items.any((item) => item.name == name),
      );
      final visible = queryLibrary(
        state.items,
        type: _type,
        search: _search,
        newest: _newest,
      );
      final busy = state.loading || state.deleting || _saving;
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: ListHeader(
                title: 'Thư viện',
                loading: busy,
                error: state.error,
                onRefresh: connection == null || busy
                    ? null
                    : () => context.read<MediaBloc>().add(
                        CollectionLoaded(connection),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Tìm theo tên tệp',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => _changeQuery(() => _search = value),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final entry in [
                        (LibraryType.all, 'Tất cả'),
                        (LibraryType.images, 'Ảnh'),
                        (LibraryType.videos, 'Video'),
                      ])
                        ChoiceChip(
                          label: Text(entry.$2),
                          selected: _type == entry.$1,
                          onSelected: _saving
                              ? null
                              : (_) => _changeQuery(() => _type = entry.$1),
                        ),
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _changeQuery(() => _newest = !_newest),
                        icon: const Icon(Icons.sort),
                        label: Text(_newest ? 'Mới nhất' : 'Thứ tự server'),
                      ),
                    ],
                  ),
                  Text(
                    '${visible.length}/${state.items.length} tệp · Đổi bộ lọc sẽ bỏ chọn. Ngày chưa rõ xếp cuối.',
                  ),
                  if (_saving) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang lưu media',
                    ),
                    Text(
                      _saveProgress ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _cancelSave = true),
                      child: const Text('Hủy lưu'),
                    ),
                  ],
                  if (_saveResults.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đã lưu ${_saveResults.where((e) => e.status == LibrarySaveStatus.saved).length}/${_saveResults.length} tệp',
                              ),
                              for (final result in _saveResults)
                                Text(
                                  '${result.name}: ${switch (result.status) {
                                    LibrarySaveStatus.saved => 'Đã lưu',
                                    LibrarySaveStatus.failed => 'Không lưu được',
                                    LibrarySaveStatus.skipped => 'Bỏ qua: đã tồn tại hoặc trùng tên',
                                    LibrarySaveStatus.cancelled => 'Đã hủy / chưa lưu',
                                  }}',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            StorageUsagePanel(
              connection: connection,
              repository: widget.storageRepository,
            ),
            if (state.notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Semantics(liveRegion: true, child: Text(state.notice!)),
              ),
            if (state.deleting)
              const LinearProgressIndicator(semanticsLabel: 'Đang xóa media'),
            if (_selected.isNotEmpty && connection != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${_selected.length} tệp đã chọn'),
                    TextButton(
                      onPressed: busy ? null : () => setState(_selected.clear),
                      child: const Text('Bỏ chọn'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy || state.stale
                          ? null
                          : () => _save(connection),
                      icon: const Icon(Icons.folder_outlined),
                      label: Text('Lưu ${_selected.length} tệp vào thư mục'),
                    ),
                    FilledButton.icon(
                      onPressed: busy || state.stale
                          ? null
                          : () => _delete(connection, _selected.toList()),
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Xóa ${_selected.length} tệp'),
                    ),
                  ],
                ),
              ),
            if (connection == null)
              const SizedBox(
                height: 160,
                child: Center(child: Text('Kết nối server để xem media.')),
              )
            else if (state.items.isEmpty && !state.loading)
              const SizedBox(
                height: 160,
                child: Center(child: Text('Chưa có ảnh hoặc video.')),
              )
            else if (visible.isEmpty && !state.loading)
              const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Không có tệp phù hợp. Thử tên khác hoặc chọn Tất cả.',
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: visible.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  final uri = item.protectedUri;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: uri == null
                          ? null
                          : () => showMediaPreview(
                              context,
                              uri,
                              item.isVideo,
                              connection: connection,
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip:
                                    '${_selected.contains(item.name) ? 'Bỏ chọn' : 'Chọn'} ${item.name}',
                                isSelected: _selected.contains(item.name),
                                icon: const Icon(Icons.check_box_outline_blank),
                                selectedIcon: const Icon(Icons.check_box),
                                onPressed:
                                    busy ||
                                        state.stale ||
                                        !isDeletableMediaName(item.name)
                                    ? null
                                    : () => setState(() {
                                        if (!_selected.add(item.name)) {
                                          _selected.remove(item.name);
                                        }
                                      }),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Xóa ${item.name}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed:
                                    busy ||
                                        state.stale ||
                                        !isDeletableMediaName(item.name)
                                    ? null
                                    : () => _delete(connection, [item.name]),
                              ),
                            ],
                          ),
                          Expanded(
                            child: item.isVideo
                                ? const ColoredBox(
                                    color: StudioColors.raised,
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        size: 52,
                                      ),
                                    ),
                                  )
                                : uri == null
                                ? const Center(child: Icon(Icons.lock_outline))
                                : Image.network(
                                    uri.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(item.bytes / 1024 / 1024).toStringAsFixed(1)} MB · ${formatDate(item.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StudioColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}
