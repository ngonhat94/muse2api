import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';

import 'account_keepalive_repository_test.dart' show server;

const fullQuota = <String, dynamic>{
  'plan': 'Free plan',
  'weekly_used_pct': 12.5,
  'weekly_reset': 'Sep 30',
  'extra_used_pct': 0,
  'extra_left': '2B tokens left',
  'extra_expires': 'never',
  'checked_at': 1700000000,
  'found': true,
  'raw': 'private-cookie',
};

AccountRepositoryImpl repository(
  Object? quota, {
  List<http.Request>? requests,
}) => AccountRepositoryImpl(
  JsonApiClient(
    () => MockClient((r) async {
      requests?.add(r);
      return http.Response(
        jsonEncode({
          'accounts': [
            {'id': 'a', 'label': 'A', 'quota': quota},
          ],
        }),
        200,
      );
    }),
  ),
);

void main() {
  test('quota refresh rejects missing or invalid success evidence without retries or details', () async {
    for (final payload in [
      <String, dynamic>{},
      {'plan': 'Free plan', 'found': true, 'checked_at': 1700000000},
      {...fullQuota, 'weekly_used_pct': 101},
      {...fullQuota, 'weekly_used_pct': null},
      {...fullQuota, 'found': false},
      {...fullQuota, 'checked_at': null},
    ]) {
      var calls = 0;
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            calls++;
            expect(r.method, 'POST');
            expect(r.url.path, '/muse/admin/accounts/a%2Fb/quota');
            expect(r.body, isEmpty);
            return http.Response(
              jsonEncode({...payload, 'error': 'private-cookie'}),
              200,
            );
          }),
        ),
      );
      await expectLater(
        repo.act(server, 'a/b', AccountAction.quota),
        throwsA(predicate((e) => !e.toString().contains('private-cookie'))),
      );
      expect(calls, 1);
    }
    for (final value in [0, 100]) {
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({...fullQuota, 'weekly_used_pct': value}),
              200,
            ),
          ),
        ),
      );
      expect(
        await repo.act(server, 'a', AccountAction.quota),
        'Đã cập nhật quota.',
      );
    }
  });
  test(
    'plan-only quota response never claims success and keeps cached bloc state',
    () async {
      final requests = <http.Request>[];
      var body = <String, dynamic>{
        'plan': 'Free plan',
        'found': false,
        'raw': 'private-cookie',
      };
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(
                r.method == 'GET'
                    ? {
                        'accounts': [
                          {'id': 'a', 'quota': fullQuota},
                        ],
                      }
                    : body,
              ),
              200,
            );
          }),
        ),
      );
      final bloc = AccountBloc(ManageAccounts(repo));
      addTearDown(bloc.close);
      Future<void> tick() async {
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }

      bloc.add(AccountsLoaded(server));
      await tick();
      expect(requests.length, 1);
      final cached = bloc.state.items.single;
      bloc.add(AccountActed(server, 'a', AccountAction.quota));
      await tick();
      expect(bloc.state.error, isNotNull);
      expect(bloc.state.error, isNot(contains('private-cookie')));
      expect(bloc.state.message, isNull);
      expect(bloc.state.items.single, same(cached));
      body = {...fullQuota};
      bloc.add(AccountActed(server, 'a', AccountAction.quota));
      await tick();
      expect(bloc.state.message, 'Đã cập nhật quota.');
      expect(bloc.state.items.single.extraLeft, '2B tokens left');
      expect(bloc.state.items.single.quotaCheckedAt, cached.quotaCheckedAt);
      expect(requests.map((r) => r.method), ['GET', 'POST', 'POST', 'GET']);
    },
  );
  test(
    'partial malformed quota remains unknown and timestamps are bounded',
    () async {
      for (final invalid in [-1, 101, '0', true, null, [], {}]) {
        final dynamic a = (await repository({
          'plan': [],
          'weekly_used_pct': invalid,
          'extra_used_pct': invalid,
          'weekly_reset': {},
          'extra_left': 2000000000,
          'extra_expires': false,
          'checked_at': 1e30,
        }).list(server)).single;
        expect(a.plan, isNull);
        expect(a.weeklyUsed, isNull);
        expect(a.weeklyRemaining, isNull);
        expect(a.extraUsed, isNull);
        expect(a.extraRemaining, isNull);
        expect(a.weeklyReset, isNull);
        expect(a.extraLeft, isNull);
        expect(a.extraExpires, isNull);
        expect(a.quotaCheckedAt, isNull);
      }
      for (final value in [0, 100]) {
        final dynamic a = (await repository({
          'weekly_used_pct': value,
          'extra_used_pct': value,
        }).list(server)).single;
        expect(a.weeklyRemaining, 100 - value);
        expect(a.extraRemaining, 100 - value);
      }
      for (final q in [
        null,
        [],
        {},
        {'plan': 'Free plan', 'checked_at': 'bad'},
      ]) {
        final a = (await repository(q).list(server)).single;
        expect(a.weeklyUsed, isNull);
        expect(a.quotaCheckedAt, isNull);
      }
      for (final value in [double.nan, double.infinity, -1.0, 101.0]) {
        final dynamic a = MuseAccount(
          id: 'a',
          label: 'A',
          enabled: true,
          weeklyUsed: value,
          extraUsed: value,
        );
        expect(a.weeklyRemaining, isNull);
        expect(a.extraRemaining, isNull);
      }
    },
  );
  test('full cached quota survives repository and domain without estimating tokens', () async {
    final a = (await repository(fullQuota).list(server)).single;
    final dynamic quota = a;
    expect(a.plan, 'Free plan');
    expect(a.weeklyUsed, 12.5);
    expect(quota.weeklyRemaining, 87.5);
    expect(quota.weeklyReset, 'Sep 30');
    expect(quota.extraUsed, 0);
    expect(quota.extraRemaining, 100);
    expect(quota.extraLeft, '2B tokens left');
    expect(quota.extraExpires, 'never');
    expect(a.quotaCheckedAt?.millisecondsSinceEpoch, 1700000000000);
  });
}
