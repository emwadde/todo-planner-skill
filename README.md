# Project Todo Planner

A lightweight, file-based backlog and issue tracker for agentic coding projects. Items are plain markdown files with their state (type, priority, status) encoded directly in the filename — readable by a human, a shell script, or an AI coding agent with nothing more than `ls`.

This sits *above* whatever in-session execution checklist your coding agent already has (e.g. opencode's built-in todo tool, which tracks steps within one task). This tracks the project's actual backlog — features, issues, enhancements — across sessions, so it survives after the agent's context window doesn't.

## Why

- **No server, no database.** Just markdown files in a `.todo/` folder, committed alongside your code.
- **State is visible without opening files.** `ls .todo/` shows every item's type, priority, and status at a glance.
- **Harness-agnostic.** The CLI is pure bash + coreutils — no Node, no Python — so it works identically whether it's being driven by opencode, Claude Code, a CI script, or your own hands.

## Install

Copy this folder into your project (or wherever your agent harness expects skills/tools):

```
todo-planner/
├── README.md
├── SKILL.md          # instructions for AI agents on when/how to use this
└── scripts/
    └── todo.sh        # the CLI
```

Make the script executable (this doesn't survive a download, so it's a required first step):

```bash
chmod +x todo-planner/scripts/todo.sh
```

Optionally symlink or alias it for convenience:

```bash
alias todo='/path/to/todo-planner/scripts/todo.sh'
```

## Quick start

```bash
cd your-project
todo.sh init
todo.sh new feature "Add login page" 2
todo.sh new issue "Crash on startup" 5
todo.sh list
todo.sh next
todo.sh start 002
todo.sh done 002
```

## File format

```
.todo/{n}_{type}_{priority}_{status}_{title}.md
```

| Field      | Meaning                                                                 |
|------------|--------------------------------------------------------------------------|
| `n`        | Zero-padded, immutable ID (`001`, `002`, ...). Assigned once, never reused. Use this — not the filename — for cross-references, since renames change the filename but not the ID. |
| `type`     | `feature` \| `issue` \| `enhance`                                        |
| `priority` | Integer, default `0`. Higher = more urgent. Can be negative.             |
| `status`   | `todo` \| `doing` \| `done`                                              |
| `title`    | Lowercase, hyphen-separated slug                                         |

Example: `004_issue_5_doing_crash-on-startup.md`

Status and priority changes rename the file — always through the CLI, never by hand-editing the filename, so the ID and the rest of the fields stay consistent.

The file body is free markdown: a `# Title` heading plus `## Description` and `## Notes` sections. Don't duplicate type/priority/status inside the body — the filename is the single source of truth.

## Commands

| Command | Description |
|---|---|
| `todo.sh init` | Create `.todo/` in the current directory |
| `todo.sh new <type> "<title>" [priority]` | Create a new item, status starts at `todo` |
| `todo.sh list [--status=S] [--type=T]` | List items, highest priority first |
| `todo.sh next` | Show the single top-priority open item |
| `todo.sh show <id>` | Print an item's full file contents |
| `todo.sh start <id>` | Set status to `doing` |
| `todo.sh done <id>` | Set status to `done` |
| `todo.sh status <id> <status>` | Set status directly |
| `todo.sh priority <id> <n>` | Set priority directly |
| `todo.sh retitle <id> "<new title>"` | Change the title, keep everything else |

Set the `TODO_DIR` environment variable to use a folder other than `.todo/`.

## Using this with an AI coding agent

`SKILL.md` is written for the agent, not for you — it tells the agent when to consult this tracker (backlog requests, "what's next", filing new issues found mid-task, etc.) and how to call the CLI. Drop the whole `todo-planner/` folder wherever your harness looks for skills, plugins, or tools, and the agent picks up the instructions from there.

## Git

Renames are expected — git tracks them as renames rather than clean diffs, and any link to an old filename will break once the item's status or priority changes. Treat the immutable `{n}` ID as the durable reference (e.g. "fixes 004" in a commit message), not the filename.
