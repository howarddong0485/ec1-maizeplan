"""Shared browser/React Native HTTP client. Tokens remain in memory only.

Explicit URLs let a physical phone and the CLI reach the exact same server.
No response cache: Refresh always reads the server.
"""
import from "react" { useState }

async def:pub request(base: str, path: str, token: str, payload: dict) -> any {
    response: any = None;
    body: any = None;
    response = await fetch(base.rstrip("/") + path, {
        "method": "POST", "headers": {"Content-Type": "application/json",
        "Authorization": "Bearer " + token if token else ""},
        "body": JSON.stringify(payload)
    });
    body = await response.json();
    if not response.ok or not body["ok"] {
        raise Exception(JSON.stringify(body["error"] or body));
    }
    return body["data"];
}

async def:pub authenticate(base: str, username: str, password: str, register: bool) -> str {
    result: any = None;
    if register {
        result = await request(base, "/user/register", "", {
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}});
    }
    result = await request(base, "/user/login", "", {
        "identity": {"type": "username", "value": username},
        "credential": {"type": "password", "password": password}});
    return result["token"];
}

async def:pub rpc(base: str, token: str, name: str, payload: dict) -> any {
    result: any = None;
    result = await request(base, "/function/" + name, token, payload);
    return result["result"];
}

def:pub today() -> str {
    now = new(Date);
    return str(now.getFullYear()) + "-" + str(now.getMonth() + 1).zfill(2) + "-" + str(now.getDate()).zfill(2);
}
