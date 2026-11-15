import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/account_proxy.dart';
import '../../domain/entities/muse_account.dart';
import '../../domain/usecases/manage_proxy.dart';
import '../bloc/proxy_bloc.dart';

class ProxyEditor extends StatelessWidget {
  const ProxyEditor({
    super.key,
    required this.account,
    required this.connection,
    required this.onSaved,
    this.enabled = true,
  });
  final MuseAccount account;
  final ServerConnection connection;
  final VoidCallback onSaved;
  final bool enabled;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ProxyBloc(context.read<ManageProxy>(), connection, account.id),
    child: _ProxyForm(account: account, onSaved: onSaved, enabled: enabled),
  );
}

class _ProxyForm extends StatefulWidget {
  const _ProxyForm({
    required this.account,
    required this.onSaved,
    required this.enabled,
  });
  final MuseAccount account;
  final VoidCallback onSaved;
  final bool enabled;
  @override
  State<_ProxyForm> createState() => _ProxyFormState();
}

class _ProxyFormState extends State<_ProxyForm> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _clearPassword = false;
  @override
  void initState() {
    super.initState();
    _fill();
  }

  void _fill() {
    _server.text = widget.account.proxy?.server ?? '';
    _username.text = widget.account.proxy?.username ?? '';
    _password.clear();
    _clearPassword = false;
  }

  @override
  void didUpdateWidget(_ProxyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.proxy?.server != widget.account.proxy?.server ||
        oldWidget.account.proxy?.username != widget.account.proxy?.username ||
        oldWidget.account.proxy?.hasPassword !=
            widget.account.proxy?.hasPassword) {
      _fill();
    }
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  ProxyConfiguration _configuration() => ProxyConfiguration.parse(
    _server.text,
    _username.text,
    _password.text,
    previous: widget.account.proxy,
    clearPassword: _clearPassword,
  );
  String? _error(void Function() validate) {
    try {
      validate();
      return null;
    } catch (error) {
      return error is AppFailure
          ? error.message
          : 'Kiểm tra lại cấu hình proxy.';
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ProxyBloc, ProxyState>(
    listener: (context, state) {
      if (state.saved) {
        _password.clear();
        widget.onSaved();
      }
    },
    builder: (context, state) {
      final busy = state.busy || !widget.enabled;
      void changed(String _) => context.read<ProxyBloc>().add(ProxyEdited());
      return Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _server,
                enabled: !busy,
                autocorrect: false,
                onChanged: changed,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (_) => _error(
                  () => ProxyConfiguration.normalizeServer(_server.text),
                ),
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ proxy',
                  hintText: 'socks5://host:1080',
                  helperMaxLines: 3,
                  helperText: 'HTTP, SOCKS5 hoặc SOCKS5H; thông tin đăng nhập ở ô riêng.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                enabled: !busy,
                autocorrect: false,
                onChanged: changed,
                validator: (_) => _error(
                  () => ProxyConfiguration.validateUsername(_username.text),
                ),
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập (nếu có)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !busy && !_clearPassword,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: changed,
                validator: (_) => _error(() => _configuration()),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu proxy',
                  helperMaxLines: 3,
                  helperText: widget.account.proxy?.hasPassword == true
                      ? 'Để trống để giữ mật khẩu đã lưu khi địa chỉ và tên đăng nhập không đổi.'
                      : 'Nhập mật khẩu nếu proxy yêu cầu xác thực.',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: busy
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (widget.account.proxy?.hasPassword == true)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Xóa mật khẩu đã lưu'),
                  value: _clearPassword,
                  onChanged: busy
                      ? null
                      : (value) {
                          setState(() => _clearPassword = value ?? false);
                          changed('');
                        },
                ),
              const SizedBox(height: 16),
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (state.check != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.check!.reachable
                              ? 'Proxy kết nối được'
                              : 'Chưa kết nối được proxy',
                        ),
                        Text(
                          state.check!.sessionConfirmed
                              ? 'Phiên Muse đã xác nhận'
                              : 'Phiên Muse chưa được xác nhận',
                        ),
                        if (state.check!.exitIp != null)
                          SelectableText('IP thoát: ${state.check!.exitIp}'),
                        const SizedBox(height: 4),
                        const Text(
                          'Kiểm tra không tự lưu cấu hình hoặc xác nhận khả năng tạo media.',
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.saved)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Đã cập nhật proxy. Kiểm tra phiên trước khi tạo media.',
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            if (_form.currentState!.validate()) {
                              context.read<ProxyBloc>().add(
                                ProxySaved(_configuration()),
                              );
                            }
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu proxy'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            if (_form.currentState!.validate()) {
                              context.read<ProxyBloc>().add(
                                ProxyTestRequested(_configuration()),
                              );
                            }
                          },
                    icon: const Icon(Icons.network_check),
                    label: const Text('Kiểm tra proxy'),
                  ),
                  if (widget.account.proxy != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () =>
                                context.read<ProxyBloc>().add(ProxySaved(null)),
                      child: const Text('Gỡ proxy'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
