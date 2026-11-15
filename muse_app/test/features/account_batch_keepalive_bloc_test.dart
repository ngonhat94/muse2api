import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/accounts/domain/entities/keepalive_status.dart';
import 'package:muse_app/features/accounts/domain/repositories/batch_keepalive_repository.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_cookies_repository.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

import 'account_keepalive_bloc_test.dart' show KeepaliveRepo, tick;
import 'account_keepalive_repository_test.dart' show server;

class BatchRepo extends KeepaliveRepo
    implements BatchKeepaliveRepository, AccountCookiesRepository {
  int batches = 0, cookies = 0;
  bool batchBusy = false, batchFails = false;
  Completer<BatchKeepaliveResult>? batchPending;
  Completer<String>? cookiePending;
  @override
  Future<BatchKeepaliveResult> keepaliveAll(ServerConnection c) async {
    batches++;
    if (batchFails) {
      throw const AppFailure('Kết quả chưa xác định; không tự thử lại.');
    }
    return batchPending?.future ??
        BatchKeepaliveResult(
          busy: batchBusy,
          summary: batchBusy
              ? null
              : const KeepaliveSummary(
                  attempts: 2,
                  successes: 1,
                  failures: 1,
                  busy: 0,
                  unknown: 0,
                  skipped: 3,
                ),
        );
  }

  @override
  Future<String> updateCookies(
    ServerConnection c,
    String id,
    String cookie,
  ) async {
    cookies++;
    return cookiePending?.future ?? 'updated';
  }
}

Future<AccountBloc> batchLoaded(BatchRepo r) async {
  final b = AccountBloc(ManageAccounts(r));
  b.add(AccountsLoaded(server));
  await tick();
  return b;
}

void main() {
  test('pending cookie update blocks batch until mutation completes', () async {
    final r = BatchRepo()..cookiePending = Completer<String>();
    final b = await batchLoaded(r);
    addTearDown(b.close);
    b.add(AccountCookiesUpdated(server, 'a', 'fixture'));
    await tick();
    b.add(AccountsBatchKeepaliveRequested(server));
    await tick();
    expect(r.cookies, 1);
    expect(r.batches, 0);
    r.cookiePending!.complete('updated');
    await tick();
  });
  test(
    'connection replacement cannot overlap still-running remote batch',
    () async {
      final r = BatchRepo()..batchPending = Completer<BatchKeepaliveResult>();
      final b = await batchLoaded(r);
      addTearDown(b.close);
      b.add(AccountsBatchKeepaliveRequested(server));
      await tick();
      const replacement = ServerConnection(
        baseUrl: 'https://example.com/muse',
        apiKey: 'changed',
      );
      b.add(AccountsLoaded(replacement));
      await tick();
      b.add(AccountsBatchKeepaliveRequested(replacement));
      b.add(AccountActed(replacement, 'a', AccountAction.keepalive));
      b.add(AccountCookiesUpdated(replacement, 'a', 'fixture'));
      await tick();
      expect(r.batches, 1);
      expect(r.calls, 0);
      expect(r.cookies, 0);
      r.batchPending!.complete(const BatchKeepaliveResult(busy: true));
      await tick();
    },
  );
  test(
    'busy and uncertain outcomes do not trigger completion reload or retries',
    () async {
      for (final busy in [true, false]) {
        final r = BatchRepo()
          ..batchBusy = busy
          ..batchFails = !busy;
        final b = await batchLoaded(r);
        b.add(AccountsBatchKeepaliveRequested(server));
        await tick();
        expect(b.state.batchCompleted, false);
        expect(b.state.message, isNull);
        expect(b.state.error, isNotNull);
        expect(r.batches, 1);
        expect(r.lists, 1);
        await b.close();
      }
    },
  );
  test('individual and cookie mutations block batch', () async {
    final r = BatchRepo()..pending = Completer<String>();
    final b = await batchLoaded(r);
    addTearDown(b.close);
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    await tick();
    b.add(AccountsBatchKeepaliveRequested(server));
    await tick();
    expect(r.batches, 0);
    r.pending!.complete('done');
    await tick();
  });
  test(
    'server or credential changes suppress late results and stale events',
    () async {
      final r = BatchRepo()..batchPending = Completer<BatchKeepaliveResult>();
      final b = await batchLoaded(r);
      addTearDown(b.close);
      b.add(AccountsBatchKeepaliveRequested(server));
      await tick();
      const replacement = ServerConnection(
        baseUrl: 'https://example.com/muse',
        apiKey: 'replacement-fixture',
      );
      b.add(AccountsLoaded(replacement));
      await tick();
      b.add(AccountsBatchKeepaliveRequested(server));
      await tick();
      r.batchPending!.complete(
        const BatchKeepaliveResult(
          summary: KeepaliveSummary(
            attempts: 1,
            successes: 1,
            failures: 0,
            busy: 0,
            unknown: 0,
            skipped: 0,
          ),
        ),
      );
      await tick();
      expect(r.batches, 1);
      expect(r.lists, 2);
      expect(b.state.message, isNull);
      expect(b.state.batchCompleted, false);
    },
  );
  test('clear cancels presentation without retrying remote mutation', () async {
    final r = BatchRepo()..batchPending = Completer<BatchKeepaliveResult>();
    final b = await batchLoaded(r);
    addTearDown(b.close);
    b.add(AccountsBatchKeepaliveRequested(server));
    await tick();
    b.add(AccountsCleared());
    await tick();
    r.batchPending!.complete(const BatchKeepaliveResult(busy: true));
    await tick();
    expect(b.state.items, isEmpty);
    expect(b.state.error, isNull);
    expect(r.lists, 1);
    expect(r.batches, 1);
  });
  test('batch owns mutation guard, acknowledges partial completion and reloads separately', () async {
    final r = BatchRepo()..batchPending = Completer<BatchKeepaliveResult>();
    final b = await batchLoaded(r);
    addTearDown(b.close);
    b.add(AccountsBatchKeepaliveRequested(server));
    b.add(AccountsBatchKeepaliveRequested(server));
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    final cookie = AccountCookiesUpdated(server, 'a', 'fixture-cookie');
    b.add(cookie);
    await tick();
    expect(b.state.busy, true);
    expect(r.batches, 1);
    expect(r.calls, 0);
    expect(r.cookies, 0);
    expect(cookie.cookies, isEmpty);
    r.reloadFails = true;
    r.batchPending!.complete(
      const BatchKeepaliveResult(
        summary: KeepaliveSummary(
          attempts: 2,
          successes: 1,
          failures: 1,
          busy: 0,
          unknown: 0,
          skipped: 3,
        ),
      ),
    );
    await tick();
    expect(b.state.message, contains('1 thành công · 1 thất bại'));
    expect(b.state.message, contains('3 bỏ qua'));
    expect(b.state.batchCompleted, true);
    expect(b.state.error, contains('Không tải lại được danh sách'));
    expect(b.state.error, isNot(contains('private-reload')));
    expect(r.lists, 2);
  });
}
