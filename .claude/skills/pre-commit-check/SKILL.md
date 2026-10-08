---
name: pre-commit-check
description: The evidence gate before a commit or PR. Runs the mechanical checks nobody can eyeball: comment ratio, leftover debris, removed assertions, secrets, and whether the tests actually ran. Use when the user says commit, push, open a PR, or "is this ready".
effort: low
context: fork
background: false
disallowed-tools: Write Edit
---

# Pre-commit check

This gate reports and never edits. Findings go back as a file and a line for the caller to fix.

It checks evidence, not intent. Whether the code is the right code is the self-review step of the delivery workflow. Repeating that judgement here charges for it twice.

Every grep below is a signal, not a verdict. They match prose as well as code, and they match this file, which holds the patterns it searches for. Read each hit before reporting it.

## 1. Get the full diff, including new files

```bash
git add -A && git diff --cached
```

Staging first is the correct posture before a commit, and it is the only way a brand new file appears in the diff at all. It also works on the very first commit, where `git diff HEAD` fails because there is no HEAD yet.

## 2. Comment ratio

```bash
git diff --cached -U0 | awk '/^\+[^+]/ { t++; l=$0; sub(/^\+[ \t]*/,"",l); if (l ~ /^(\/\/|#|--|\/\*|\*|<!--|""")/) c++ } END { if (t) printf "added=%d comment=%d ratio=%d%%\n", t, c, c*100/t }'
```

Report the number. Above 10 percent, list the offending comments so the caller can cut them. Aim for 5 percent on anything sizeable.

Markdown headings and YAML keys inflate this, and trailing comments after code are missed entirely. Under 50 added lines it swings on a single comment. Treat it as a reason to look, never as a verdict.

## 3. Debris

```bash
git diff --cached -U0 | grep -nE '^\+.*(TODO|FIXME|XXX|console\.log|debugger|var_dump|print\(|printf\(|fmt\.Print)' | head -20
```

Report every hit with its file and line. A marker that predates this change is fine. One this change introduced is not.

## 4. Tests

Answer all three:

- Does every behavior change in the diff have a test in the same diff? Name the ones that do not.
- Was each test actually run, with output? If you cannot point at the run, report it as unverified rather than assuming it passed.
- Did any existing assertion get removed, skipped, or loosened?

```bash
git diff --cached -U0 | grep -nE '^-.*(assert|expect|it\(|test\(|def test)' | head -20
```

Deleted assertions surface here. Every hit needs an explanation.

## 5. Secrets

```bash
git diff --cached | grep -nEi '(api[_-]?key|secret|token|password|BEGIN [A-Z ]*PRIVATE KEY)'
```

Any hit is a stop. Report the file and line only, never the value.

## 6. Report

State what passed, what failed, what you did not check, and the comment ratio you measured.

Then stop. Committing needs a separate go-ahead.
