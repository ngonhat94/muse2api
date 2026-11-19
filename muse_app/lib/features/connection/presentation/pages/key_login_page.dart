import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/connection_bloc.dart';
import '../widgets/shiba_loading.dart';

/// Public web entry point. No feature widgets or credential prefill live here.
class KeyLoginPage extends StatefulWidget {
  const KeyLoginPage({super.key});

  @override
  State<KeyLoginPage> createState() => _KeyLoginPageState();
}

class _KeyLoginPageState extends State<KeyLoginPage> {
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  void _submit(bool busy) {
    if (busy) return;
    final bloc = context.read<ConnectionBloc>();
    bloc.add(ConnectionRequested(bloc.sharedAddress, _key.text.trim()));
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ConnectionBloc, ServerConnectionState>(
        builder: (context, state) {
          if (state.restoring) return const ShibaLoadingPage();
          final busy =
              state.status == ConnectionStatus.connecting ||
              state.loggingOut ||
              state.credentialRemovalFailed;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Muse Studio',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _key,
                              enabled: !busy,
                              obscureText: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(busy),
                              decoration: const InputDecoration(
                                labelText: 'API key',
                              ),
                            ),
                            if (state.error != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  state.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            if (state.credentialRemovalFailed)
                              TextButton(
                                onPressed: () => context
                                    .read<ConnectionBloc>()
                                    .add(LogoutRequested()),
                                child: const Text('Thử xóa API key lại'),
                              ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: busy ? null : () => _submit(busy),
                              child: state.credentialRemovalFailed
                                  ? const Text('Đăng nhập')
                                  : busy
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Vui lòng chờ…'),
                                      ],
                                    )
                                  : const Text('Đăng nhập'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
