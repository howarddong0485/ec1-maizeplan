"""Sample-week API/CLI regression using disposable accounts on a running server."""
import argparse
import json
import os
import secrets
import subprocess
from datetime import date, timedelta
from smoke_test import call


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', default='http://127.0.0.1:8001')
    args = parser.parse_args()

    def account():
        username = 'maize_sample_' + secrets.token_hex(8)
        credential = {'type': 'password', 'password': secrets.token_urlsafe(24)}
        status, body = call(args.server, '/user/register', {
            'identities': [{'type': 'username', 'value': username}], 'credential': credential})
        assert status == 201 and body['ok']
        status, body = call(args.server, '/user/login', {
            'identity': {'type': 'username', 'value': username}, 'credential': credential})
        assert status == 200 and body['ok']
        return body['data']['token']

    def rpc(name, payload, token):
        status, body = call(args.server, '/function/' + name, payload, token)
        assert status == 200 and body['ok'], (name, status, body)
        return body['data']['result']

    def rejected(payload, token):
        status, body = call(args.server, '/function/load_sample', payload, token)
        assert status >= 400 or not body.get('ok'), (status, body)

    def snapshot(token):
        return [rpc('list_tasks', {'include_archived': True}, token),
                rpc('list_sessions', {}, token), rpc('get_capacity', {}, token)]

    today = date.today().isoformat()
    token = account()
    rejected({'day': today}, '')
    rejected({'day': '2026-02-30'}, token)
    assert snapshot(token)[0] == []
    proc = subprocess.run(['jac', 'run', 'cli', '--server', args.server, '--json',
                           'sample', '--day', today],
                          env={**os.environ, 'MAIZEPLAN_TOKEN': token},
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == 0, proc.stderr
    sample = json.loads(proc.stdout)
    assert sample['created'] and sample['day'] == today
    plan = rpc('week_plan', {'start': today}, token)
    assert [d['budget'] for d in plan['days']] == [25, 120, 0, 0, 0, 0, 0]
    assert plan['study'] == 90 and plan['deadline_shortfall'] == 65
    assert plan['remaining'] == 0
    rpc('log_study', {'task_id': sample['task_id'], 'minutes': 25,
                     'day': today, 'request_id': 'sample-progress'}, token)
    assert rpc('week_plan', {'start': today}, token)['deadline_shortfall'] == 40
    rpc('archive_task', {'task_id': sample['task_id'], 'archived': True}, token)
    rpc('save_capacity', {'budgets': [60] * 7}, token)
    before = snapshot(token)
    retry = rpc('load_sample', {'day': (date.today() + timedelta(days=1)).isoformat()}, token)
    assert not retry['created'] and retry['task_id'] == sample['task_id']
    assert retry['day'] == today and snapshot(token) == before

    # Ordinary data and capacity-only accounts must remain byte-for-byte unchanged.
    for kind in ('task', 'capacity'):
        other = account()
        assert snapshot(other)[0] == []
        if kind == 'task':
            task = rpc('save_task', {'title': 'Keep my work', 'course': '', 'due': today,
                                    'priority': 2, 'minutes': 30}, other)
            rpc('archive_task', {'task_id': task['id'], 'archived': True}, other)
        else:
            rpc('save_capacity', {'budgets': [30] * 7}, other)
        before = snapshot(other)
        rejected({'day': today}, other)
        assert snapshot(other) == before

    # Sunday -> Monday must rotate into a Monday-first stored routine.
    other = account()
    rpc('load_sample', {'day': '2026-10-04'}, other)
    assert rpc('get_capacity', {}, other)['budgets'] == [120, 0, 0, 0, 0, 0, 25]
    assert len(rpc('list_tasks', {}, other)) == 1
    assert snapshot(token) != snapshot(other)
    print('PASS: sample API/CLI, 65→40 shortfall, weekday rotation, account isolation, '
          'retry preservation and nonempty-account protection.')


if __name__ == '__main__':
    main()
