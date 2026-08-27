---
name: project-todo-planner
description: Manage a project's own backlog of features, issues, and enhancements as markdown files in .todo/, with status and priority encoded directly in each filename. Use this whenever the user wants to plan, track, prioritize, log, or update project-level work items — as opposed to an in-session execution checklist for a single task. Trigger on phrases like "add this to the backlog", "create a ticket/issue for X", "what should I work on next", "mark this as done/in progress", "what's the project status", "list open issues", or any request to persist a piece of work across sessions. Always use the bundled todo.sh script rather than hand-editing or hand-renaming files.
---

# Project Todo Planner

A project-level backlog and issue tracker that lives inside the project itself, as plain markdown files. This is separate from — and sits above — any in-session subtask checklist your harness provides (e.g. opencode's built-in todo tool). That tool tracks steps *within* one task; this tracks the backlog *across* sessions.

## File format

Items live in `.todo/` at the project root, one file per item:

```
{n}_{type}_{priority}_{status}_{title}.md
```

- **n** — zero-padded 3-digit ID (`001`, `002`, ...). Immutable once assigned: it never changes and is never reused, even if the item is deleted. This is the item's permanent identifier — use it in cross-references (e.g. "blocks 007", "see 003") since renames change the filename but not the ID.
- **type** — one of `feature`, `issue`, `enhance`.
- **priority** — integer, default `0` (neutral). Higher = more urgent. Can be negative for below-neutral items.
- **status** — one of `todo`, `doing`, `done`.
- **title** — lowercase, hyphen-separated slug.

Example: `004_issue_5_doing_crash-on-startup.md`

All state is encoded in the filename by design, so any agent can see the full backlog state with a plain `ls .todo/` — no need to open files. Status and priority changes are file **renames**, done through the script below, never by hand-editing the filename.

The file body itself is free-form: a `# Title` heading plus `## Description` and `## Notes` sections. Don't duplicate the filename's metadata (type/priority/status) inside the body — the filename is the single source of truth, and a duplicated copy will drift out of sync.

## Using the CLI

Everything goes through `scripts/todo.sh`, a dependency-free bash script (bash 4+, coreutils only — no Node/Python required, so it runs the same in any harness that can execute shell commands).

```
todo.sh init                            # create .todo/ in the current project
todo.sh new <type> "<title>" [priority] # create a new item, status=todo
todo.sh list [--status=S] [--type=T]    # list items, highest priority first
todo.sh next                            # show the single top-priority open item
todo.sh show <id>                       # print an item's full file contents
todo.sh start <id>                      # status -> doing
todo.sh done <id>                       # status -> done
todo.sh status <id> <status>            # set status directly
todo.sh priority <id> <n>               # set priority directly
todo.sh retitle <id> "<new title>"      # rename the title, keeps id/type/priority/status
```

Run it from the project root (it looks for `.todo/` relative to the current directory), or set `TODO_DIR` to point elsewhere.

## Agent workflow

- **Starting a session**: run `todo.sh next` to pick up the highest-priority open item, or `todo.sh list --status=todo` to see the full open backlog before choosing.
- **Beginning work on an item**: `todo.sh start <id>`, then read it with `todo.sh show <id>`.
- **Finding new work mid-task**: don't just fix things silently — file them, e.g. `todo.sh new issue "null check missing on upload handler" 2`, so nothing found along the way gets lost.
- **Finishing**: `todo.sh done <id>`. Add a line to the item's `## Notes` section first if there's context worth keeping (what changed, why, follow-ups).
- **Re-prioritizing**: `todo.sh priority <id> <n>` any time priorities shift — don't hand-edit filenames.

## Notes on git

Status/priority/title changes rename the file, so git records them as renames rather than clean diffs, and a link to an old filename will 404 after a rename. This is expected — treat the immutable `{n}` ID, not the filename, as the durable reference for cross-links and commit messages (e.g. "fixes 004" rather than "fixes crash-on-startup").
