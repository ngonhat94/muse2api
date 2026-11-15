import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/entities/account_import_draft.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const server = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'fixture',
);
const batch =
    'acc-01 | hatch_sess=first; hatch_vml=vm1\nacc-02 | hatch_sess=second; hatch_vml=vm2';

class ImportRepo implements AccountRepository {
  int posts = 0;
  bool fail = false;
  bool failReload = false;
  Completer<String>? pending;
  @override
  Future<List<MuseAccount>> list(ServerConnection c) async {
    if (failReload && posts > 0) throw const AppFailure('network fixture');
    return [const MuseAccount(id: 'a', label: 'A', enabled: true)];
  }

  @override
  Future<String> import(ServerConnection c, String label, String input) async {
    posts++;
    if (fail) throw const AppFailure('sensitive-fixture');
    return pending?.future ?? 'Đã nhập 2 tài khoản.';
  }

  @override
  Future<String> act(ServerConnection c, String id, AccountAction action) =>
      throw UnimplementedError();
}

Future<AccountBloc> loaded(ImportRepo repo) async {
  final bloc = AccountBloc(ManageAccounts(repo));
  final ready = bloc.stream.firstWhere((s) => !s.busy && s.items.isNotEmpty);
  bloc.add(AccountsLoaded(server));
  await ready;
  return bloc;
}

void main() {
  test(
    'Single header preserves label, equals signs and literal pipe values',
    () {
      final draft = AccountImportDraft.parse(
        ' My account ',
        ' hatch_sess=a=b|c; hatch_vml=vm ',
      );
      expect(draft.isBatch, false);
      expect(draft.accountCount, 1);
      expect(draft.label, 'My account');
      expect(draft.text, 'hatch_sess=a=b|c; hatch_vml=vm');
      expect(draft.toString(), isNot(contains('a=b|c')));
    },
  );
  test(
    'Named batch supports CRLF, blanks and comments and ignores external label',
    () {
      final draft = AccountImportDraft.parse(
        'unused',
        '\r\n# imported list\r\nacc-01 | hatch_sess=first\r\n\r\nacc-02 | hatch_sess=second\r\n',
      );
      expect(draft.isBatch, true);
      expect(draft.accountCount, 2);
      expect(draft.label, '');
      expect(
        draft.text,
        'acc-01 | hatch_sess=first\nacc-02 | hatch_sess=second',
      );
    },
  );
  test('One named row and optional names use batch semantics', () {
    final one = AccountImportDraft.parse('unused', 'acc-01 | hatch_sess=first');
    expect(one.isBatch, true);
    expect(one.accountCount, 1);
    final mixed = AccountImportDraft.parse(
      'unused',
      'acc-01 | hatch_sess=first\nhatch_sess=second',
    );
    expect(mixed.accountCount, 2);
    expect(mixed.isBatch, true);
  });
  test('Unlabelled complete sessions are batch; separate cookie pairs stay one account', () {
    expect(
      AccountImportDraft.parse(
        '',
        'hatch_sess=first\nhatch_sess=second',
      ).accountCount,
      2,
    );
    final single = AccountImportDraft.parse(
      'Single',
      'hatch_sess=first\nhatch_vml=vm',
    );
    expect(single.isBatch, false);
    expect(single.text, 'hatch_sess=first; hatch_vml=vm');
  });
  test('JSON dictionaries remain single-account imports', () {
    final draft = AccountImportDraft.parse(
      'JSON',
      '{\n "hatch_sess": "fixture",\n "hatch_vml": "vm"\n}',
    );
    expect(draft.isBatch, false);
    expect(draft.accountCount, 1);
    expect(jsonDecode(draft.text)['hatch_vml'], 'vm');
  });
  test(
    'Malformed lines fail before POST and errors never include cookie values',
    () async {
      var calls = 0;
      final manage = ManageAccounts(
        AccountRepositoryImpl(
          JsonApiClient(
            () => MockClient((_) async {
              calls++;
              return http.Response('{}', 200);
            }),
          ),
        ),
      );
      for (final input in [
        '',
        '  # comment  ',
        '{}',
        '{broken',
        'acc-01 | hatch_sess=sensitive-fixture\nacc-02 | malformed',
      ]) {
        await expectLater(
          manage.import(server, '', input),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('sensitive-fixture')),
            ),
          ),
        );
      }
      expect(calls, 0);
      expect(
        () => AccountImportDraft.parse(
          '',
          'acc-01 | hatch_sess=first\n\nacc-02 | missing',
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'line',
            contains('Dòng 3'),
          ),
        ),
      );
    },
  );
  test(
    'Single and batch requests each POST once with mutually exclusive fields',
    () async {
      final requests = <http.Request>[];
      final repository = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((request) async {
            requests.add(request);
            final isBatch = jsonDecode(request.body).containsKey('batch');
            return http.Response(
              jsonEncode({'count': isBatch ? 2 : 1, 'essential_missing': []}),
              200,
            );
          }),
        ),
      );
      await repository.import(
        server,
        ' Single ',
        ' hatch_sess=one; hatch_vml=vm ',
      );
      final message = await repository.import(
        server,
        'must-not-be-sent',
        batch,
      );
      expect(requests.length, 2);
      expect(requests.every((r) => r.method == 'POST'), true);
      expect(
        requests.last.url.toString(),
        'https://example.com/muse/admin/accounts',
      );
      expect(jsonDecode(requests.first.body), {
        'label': 'Single',
        'cookie_header': 'hatch_sess=one; hatch_vml=vm',
      });
      expect(jsonDecode(requests.last.body), {'batch': batch});
      expect(message, contains('2 tài khoản'));
      expect(message, isNot(contains('first')));
    },
  );
  test('Unconfirmed or partial acknowledgements never claim full import and do not retry', () async {
    for (final response in [
      <String, dynamic>{},
      {'count': 0},
      {'count': 1},
      {'count': '2'},
      {'count': 2, 'added': []},
      {
        'count': 2,
        'added': [
          {'id': 'a'},
          {'id': ''},
        ],
      },
    ]) {
      var calls = 0;
      final repository = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async {
            calls++;
            return http.Response(jsonEncode(response), 200);
          }),
        ),
      );
      await expectLater(
        repository.import(server, '', batch),
        throwsA(isA<AppFailure>()),
      );
      expect(calls, 1);
    }
  });
  test(
    'Missing essential cookie warning retains exact accepted count',
    () async {
      final repository = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient(
            (_) async => http.Response(
              '{"count":2,"essential_missing":["hatch_sess"]}',
              200,
            ),
          ),
        ),
      );
      final message = await repository.import(server, '', batch);
      expect(message, contains('2 tài khoản'));
      expect(message, contains('thiếu cookie'));
      expect(message, isNot(contains('hợp lệ')));
    },
  );
  test('BLoC clears sensitive event payload, blocks duplicates/stale session and drops late results', () async {
    final repo = ImportRepo()..pending = Completer<String>();
    final bloc = await loaded(repo);
    addTearDown(bloc.close);
    final event = AccountImported(server, '', batch);
    final started = bloc.stream.firstWhere((s) => s.busy);
    bloc.add(event);
    bloc.add(AccountImported(server, '', batch));
    await started;
    await Future<void>.delayed(Duration.zero);
    expect(event.cookies, '');
    expect(event.toString(), isNot(contains('first')));
    expect(repo.posts, 1);
    final cleared = bloc.stream.firstWhere((s) => !s.busy && s.items.isEmpty);
    bloc.add(AccountsCleared());
    await cleared;
    repo.pending!.complete('Accepted');
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.imported, false);
    final stale = AccountImported(server, '', batch);
    bloc.add(stale);
    await Future<void>.delayed(Duration.zero);
    expect(repo.posts, 1);
    expect(stale.cookies, '');
  });
  test(
    'BLoC keeps parser errors local and does not expose backend cookie errors',
    () async {
      final repo = ImportRepo();
      final bloc = await loaded(repo);
      addTearDown(bloc.close);
      final invalid = bloc.stream.firstWhere((s) => s.error != null);
      bloc.add(AccountImported(server, '', 'acc | missing'));
      await invalid;
      expect(repo.posts, 0);
      expect(bloc.state.error, contains('Dòng 1'));
      repo.fail = true;
      final failed = bloc.stream.firstWhere(
        (s) => s.error != null && !s.error!.contains('Dòng'),
      );
      bloc.add(AccountImported(server, '', batch));
      await failed;
      expect(bloc.state.error, isNot(contains('sensitive-fixture')));
      expect(bloc.state.imported, false);
    },
  );
  test('Successful import plus failed refresh is acknowledged without resubmission', () async {
    final repo = ImportRepo()..failReload = true;
    final bloc = await loaded(repo);
    addTearDown(bloc.close);
    final accepted = bloc.stream.firstWhere((s) => s.imported);
    bloc.add(AccountImported(server, '', batch));
    await accepted;
    expect(bloc.state.message, contains('2 tài khoản'));
    expect(bloc.state.error, contains('không gửi lại'));
    expect(repo.posts, 1);
  });
}
