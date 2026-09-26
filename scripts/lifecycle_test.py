"""Real API/CLI checks for weekly capacity, study revisions and task archives.

Creates disposable accounts. Optional restart state contains a test token only;
keep it under ignored .jac/. Run against a local development server.
"""
import argparse
import json
import os
import secrets
import subprocess
from datetime import date, timedelta
from pathlib import Path
from smoke_test import call


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', default='http://127.0.0.1:8001')
    state = parser.add_mutually_exclusive_group()
    state.add_argument('--write-restart-state', type=Path)
    state.add_argument('--verify-restart-state', type=Path)
    args = parser.parse_args()

    def rpc(name, payload, token):
        status, body = call(args.server, '/function/' + name, payload, token)
        assert status == 200 and body['ok'], (name, status, body)
        return body['data']['result']

    def snapshot(token):
        return {'capacity': rpc('get_capacity', {}, token),
                'tasks': rpc('list_tasks', {'include_archived': True}, token),
                'sessions': rpc('list_sessions', {}, token)}

    if args.verify_restart_state:
        saved = json.loads(args.verify_restart_state.read_text())
        assert saved['server'] == args.server
        assert snapshot(saved['token']) == saved['snapshot']
        replay = rpc('revise_study', saved['retry'], saved['token'])
        assert replay in saved['snapshot']['sessions']
        assert snapshot(saved['token']) == saved['snapshot']
        print('PASS: saved capacity, archives, study audit and correction retry survive restart.')
        return

    tokens = []
    for label in ('a', 'b'):
        username = 'maize_lifecycle_' + secrets.token_hex(6) + label
        credential = {'type': 'password', 'password': secrets.token_urlsafe(24)}
        status, body = call(args.server, '/user/register', {
            'identities': [{'type': 'username', 'value': username}], 'credential': credential})
        assert status == 201 and body['ok']
        status, body = call(args.server, '/user/login', {
            'identity': {'type': 'username', 'value': username}, 'credential': credential})
        assert status == 200 and body['ok']
        tokens.append(body['data']['token'])
    token, other = tokens
    today = date.today().isoformat()

    def cli(*command, raw=False):
        cmd = ['jac', 'run', 'cli', '--server', args.server]
        p = subprocess.run(cmd + ([] if raw else ['--json']) + list(command),
                           env={**os.environ, 'MAIZEPLAN_TOKEN': token}, text=True,
                           capture_output=True, timeout=60)
        assert p.returncode == 0, p.stderr
        return p.stdout if raw else json.loads(p.stdout)

    def rejected(name, payload, caller=token):
        status, body = call(args.server, '/function/' + name, payload, caller)
        assert status >= 400 or not body.get('ok'), (name, status, body)

    def get_task(task_id):
        return next(t for t in rpc('list_tasks', {'include_archived': True}, token)
                    if t['id'] == task_id)

    def add(title, minutes):
        return rpc('save_task', {'title': title, 'course': 'TEST', 'due': today,
                                'priority': 2, 'minutes': minutes}, token)

    def log(task, minutes, key):
        return rpc('log_study', {'task_id': task['id'], 'minutes': minutes,
                                'day': today, 'request_id': key}, token)

    def revise(s, minutes, key, voided=False):
        return rpc('revise_study', {'session_id': s['id'], 'minutes': minutes,
                                   'day': today, 'voided': voided,
                                   'expected_version': s['version'], 'request_id': key}, token)

    default = cli('capacity')
    assert default == {'budgets': [60, 60, 60, 60, 60, 0, 0], 'saved': False}
    pattern = [30, 60, 90, 120, 150, 0, 0]
    saved = cli('capacity', '--budgets', ','.join(map(str, pattern)))
    assert saved == {'budgets': pattern, 'saved': True}
    assert rpc('get_capacity', {}, other) == default
    start = '2026-09-30'  # Wednesday; canonical capacities are Monday first.
    week = cli('week', '--start', start)
    assert [d['budget'] for d in week['days']] == [90, 120, 150, 0, 0, 30, 60]
    assert week == rpc('week_plan', {'start': start}, token)
    assert week == rpc('week_plan', {'start': start, 'budgets': None}, token)
    rejected('week_plan', {'start': start, 'budgets': []})
    cli('week', '--start', start, '--budgets', '25,0')
    assert cli('capacity') == saved, 'Forecast override changed the saved routine'
    for budgets in ([], [60] * 6, [60] * 8, [4] * 7, [-1] * 7, [721] * 7):
        rejected('save_capacity', {'budgets': budgets})

    task = add('Lifecycle', 90)
    record = log(task, 25, 'original')
    correction = {'session_id': record['id'], 'minutes': 10, 'day': today,
                  'voided': False, 'expected_version': 0, 'request_id': 'correct'}
    for name, payload in [('get_capacity', {}), ('save_capacity', {'budgets': pattern}),
                          ('revise_study', correction),
                          ('archive_task', {'task_id': task['id']})]:
        rejected(name, payload, '')
    rejected('archive_task', {'task_id': task['id']}, other)
    rejected('revise_study', correction, other)
    for minutes in (0, -1, 1441):
        rejected('revise_study', {**correction, 'minutes': minutes})
    rejected('revise_study', {**correction, 'day': '2026-02-30'})
    rejected('revise_study', {**correction, 'day': (date.today() + timedelta(days=1)).isoformat()})
    s = cli('correct', record['id'], '--minutes', '10', '--day', today,
            '--version', '0', '--request-id', 'correct')
    assert s['version'] == 1 and s['remaining_delta'] == 15
    assert s['original_minutes'] == 25 and len(s['changes']) == 1
    assert get_task(task['id'])['minutes'] == 80
    assert rpc('revise_study', correction, token) == s
    rejected('revise_study', {**correction, 'request_id': 'stale'})
    rejected('revise_study', {**correction, 'minutes': 15})
    replay = rpc('log_study', {'task_id': task['id'], 'minutes': 25,
                             'day': today, 'request_id': 'original'}, token)
    assert replay == s and get_task(task['id'])['minutes'] == 80
    s = cli('undo-study', s['id'], '--version', '1', '--request-id', 'undo')
    assert s['voided'] and s['credited'] == 0 and get_task(task['id'])['minutes'] == 90
    s = cli('correct', s['id'], '--minutes', '10', '--version', '2', '--request-id', 'restore')
    assert not s['voided'] and s['credited'] == 10 and get_task(task['id'])['minutes'] == 80
    history = cli('history')
    assert len(history) == 1 and len(history[0]['changes']) == 3
    assert 'Revision 3' in cli('history', '--audit', raw=True)

    cli('archive', task['id'])
    assert rpc('archive_task', {'task_id': task['id']}, token)['archived'] is True
    assert rpc('list_tasks', {}, token) == []
    assert cli('list', '--all') == []
    assert cli('list', '--archived')[0]['id'] == task['id']
    assert cli('plan', '--day', today)['blocks'] == []
    assert cli('week', '--start', today)['risks'] == []
    assert cli('history') == history
    rejected('log_study', {'task_id': task['id'], 'minutes': 5, 'day': today, 'request_id': 'archived'})
    rejected('set_done', {'task_id': task['id'], 'done': True})
    rejected('save_task', {'task_id': task['id'], 'title': 'Archived edit', 'course': '',
                           'due': today, 'priority': 2, 'minutes': 80})
    s = revise(s, 10, 'undo-archived', True)
    assert get_task(task['id'])['archived'] and get_task(task['id'])['minutes'] == 90
    cli('restore', task['id'])
    assert cli('list')[0]['minutes'] == 90
    s = revise(s, 10, 'restore-again')
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    retry = {'session_id': s['id'], 'minutes': 10, 'day': yesterday,
             'voided': False, 'expected_version': s['version'], 'request_id': 'move-date'}
    s = rpc('revise_study', retry, token)
    assert s['day'] == yesterday and s['remaining_delta'] == 0
    cli('archive', task['id'])

    overrun = add('Overrun', 30)
    over = log(overrun, 100, 'overrun')
    assert over['credited'] == 30 and get_task(overrun['id'])['done']
    over = revise(over, 100, 'undo-overrun', True)
    assert get_task(overrun['id'])['minutes'] == 30 and not get_task(overrun['id'])['done']
    over = revise(over, 10, 'restore-overrun')
    assert get_task(overrun['id'])['minutes'] == 20
    rpc('set_done', {'task_id': overrun['id'], 'done': True}, token)
    over = revise(over, 10, 'undo-manual-done', True)
    assert get_task(overrun['id'])['minutes'] == 30 and get_task(overrun['id'])['done']

    manual = add('Manual reestimate', 60)
    m = log(manual, 20, 'manual')
    rpc('save_task', {'task_id': manual['id'], 'title': manual['title'], 'course': 'TEST',
                     'due': today, 'priority': 2, 'minutes': 100}, token)
    m = revise(m, 10, 'manual-correct')
    assert not m['estimate_adjusted'] and m['remaining_delta'] == 0
    m = revise(m, 10, 'manual-undo', True)
    assert get_task(manual['id'])['minutes'] == 100
    assert rpc('list_sessions', {}, other) == []
    assert 'Workload: # focus' in cli('week', '--start', today, raw=True)
    assert 'Active focus total:' in cli('history', raw=True)

    if args.write_restart_state:
        args.write_restart_state.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(args.write_restart_state, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.chmod(args.write_restart_state, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump({'server': args.server, 'token': token, 'retry': retry,
                       'snapshot': snapshot(token)}, stream)
    print('PASS: saved/rotated capacity, archive/restore, correction/undo/restore, immutable audit,')
    print('credited-minute caps, manual reestimate/completion preservation, stale versions, retries,')
    print('input validation, account isolation, forecast immutability and CLI/API parity.')


if __name__ == '__main__':
    main()
