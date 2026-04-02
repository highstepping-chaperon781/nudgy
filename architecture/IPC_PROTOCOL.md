# IPC Protocol — AI Coding Agent ↔ Nudgy

## Overview

Communication is one-directional: AI coding agent hooks POST JSON to
Nudgy's HTTP server. Nudgy responds with 200 OK and
processes the event asynchronously.

## Hook Configuration

Nudgy installs the following hooks into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ]
  }
}
```

## Event Payloads

### Stop (Claude finished responding)

```json
{
  "hook_event_name": "Stop",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "permission_mode": "default",
  "stop_hook_active": false
}
```

### Notification — Permission Prompt

```json
{
  "hook_event_name": "Notification",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "matcher": "permission_prompt"
}
```

### Notification — Idle Prompt (Claude asking a question)

```json
{
  "hook_event_name": "Notification",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "matcher": "idle_prompt"
}
```

### StopFailure (Error during generation)

```json
{
  "hook_event_name": "StopFailure",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "matcher": "rate_limit"
}
```

### SessionStart

```json
{
  "hook_event_name": "SessionStart",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "matcher": "startup"
}
```

### SessionEnd

```json
{
  "hook_event_name": "SessionEnd",
  "session_id": "abc-123-def",
  "cwd": "/Users/dev/myproject",
  "matcher": "prompt_input_exit"
}
```

## HTTP Protocol

### Request

```
POST /event HTTP/1.1
Host: 127.0.0.1:9847
Content-Type: application/json
Content-Length: <N>

<JSON body>
```

### Response (always)

```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 15
Connection: close

{"status":"ok"}
```

### Error Response (invalid token)

```
HTTP/1.1 401 Unauthorized
Content-Length: 0
Connection: close
```

## Event → State Mapping

| hook_event_name | matcher              | → SessionState        | Notification |
|-----------------|----------------------|-----------------------|-------------|
| SessionStart    | startup              | .active               | Silent      |
| SessionStart    | resume               | .active               | Silent      |
| Stop            | —                    | .idle                 | Success     |
| Notification    | permission_prompt    | .waitingPermission    | Warning     |
| Notification    | idle_prompt          | .waitingInput         | Question    |
| Notification    | auth_success         | (no state change)     | Silent      |
| StopFailure     | rate_limit           | .error                | Error       |
| StopFailure     | server_error         | .error                | Error       |
| StopFailure     | max_output_tokens    | .idle (partial done)  | Info        |
| SessionEnd      | *                    | .stopped              | Silent      |

## Graceful Degradation

If Nudgy is not running, the HTTP POST will fail with connection
refused. AI coding agent hooks should handle this gracefully (the `|| true`
pattern or the hook system's built-in error handling). The hook failure
must NOT block AI coding agent operation.

The `"type": "http"` hook type in AI coding agent already handles connection
failures gracefully — the hook is fire-and-forget with a timeout.
