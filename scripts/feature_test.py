"""Real API/CLI checks for study records and multi-day planning.

Creates two disposable development accounts. Does not read real credentials.
Optional restart-state contains only a test token and snapshots; keep under .jac/.
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

    if args.verify_restart_state:
        saved = json.loads(args.verify_restart_state.read_text())
        assert saved['server'] == args.server
        assert rpc('list_tasks', {}, saved['token']) == saved['tasks']
        assert rpc('list_sessions', {}, saved['token']) == saved['sessions']
        replay = rpc('log_study', saved['last_payload'], saved['token'])
        assert replay in saved['sessions']
        assert rpc('list_tasks', {}, saved['token']) == saved['tasks']
        print('PASS: task state, study history and retry identity survive server restart.')
        return

    tokens = []
    for label in ('a', 'b'):
        username = 'maize_features_' + secrets.token_hex(6) + label
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

    def cli(*command):
        p = subprocess.run(['jac', 'run', 'cli', '--server', args.server, '--json', *command],
                           env={**os.environ, 'MAIZEPLAN_TOKEN': token}, text=True,
                           capture_output=True, timeout=60)
        assert p.returncode == 0, p.stderr
        return json.loads(p.stdout)

    def rejected(name, payload, caller=token):
        status, body = call(args.server, '/function/' + name, payload, caller)
        assert status >= 400 or not body.get('ok'), (name, status, body)

    task = cli('add', 'Study loop', '--due', today, '--minutes', '90')
    payload = {'task_id': task['id'], 'minutes': 25, 'day': today, 'request_id': 'first'}
    for endpoint in ('list_sessions', 'week_plan', 'log_study'):
        rejected(endpoint, payload if endpoint == 'log_study' else {}, '')
    rejected('log_study', payload, other)
    for value in (0, -1, 1441):
        rejected('log_study', {**payload, 'minutes': value})
    rejected('log_study', {**payload, 'day': '2026-02-30'})
    rejected('log_study', {**payload, 'day': (date.today() + timedelta(days=1)).isoformat()})
    record = cli('study', task['id'], '--minutes', '25', '--day', today, '--request-id', 'first')
    assert record['credited'] == 25
    assert rpc('log_study', payload, token) == record
    rejected('log_study', {**payload, 'minutes': 30})
    assert cli('list')[0]['minutes'] == 65
    assert len(cli('history')) == 1
    assert rpc('list_sessions', {}, other) == []
    plan = cli('week', '--start', today, '--budgets', '25,120')
    assert plan == rpc('week_plan', {'start': today, 'budgets': [25, 120]}, token)
    assert plan['deadline_shortfall'] == 40 and plan['remaining'] == 0
    assert plan['days'][1]['blocks'][0]['overdue']
    assert cli('list')[0]['minutes'] == 65, 'Forecast mutated stored estimate'
    assert rpc('week_plan', {'start': today, 'budgets': [0, 0]}, other)['risks'] == []
    for budgets in ([], [-1], [4], [721], [60] * 15):
        rejected('week_plan', {'start': today, 'budgets': budgets})
    last_payload = {**payload, 'minutes': 100, 'request_id': 'finish'}
    finish = rpc('log_study', last_payload, token)
    assert finish['minutes'] == 100 and finish['credited'] == 65
    assert cli('list') == []
    finished = cli('list', '--all')[0]
    assert finished['minutes'] == 0 and finished['done']
    assert sum(s['minutes'] for s in cli('history')) == 125
    rejected('set_done', {'task_id': task['id'], 'done': False})
    rejected('log_study', {**payload, 'request_id': 'already-done'})
    assert rpc('log_study', last_payload, token) == finish
    assert len(cli('history')) == 2

    if args.write_restart_state:
        args.write_restart_state.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(args.write_restart_state, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.chmod(args.write_restart_state, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump({'server': args.server, 'token': token, 'last_payload': last_payload,
                       'tasks': rpc('list_tasks', {}, token),
                       'sessions': rpc('list_sessions', {}, token)}, stream)
    print('PASS: study history, remaining effort, auto-completion, retry deduplication,')
    print('account isolation, input validation, weekly shortfalls, day off and CLI/API parity.')


if __name__ == '__main__':
    main()
