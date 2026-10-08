# AGENTS.md

Rules the code cannot tell you. Read the code for everything else.

## Scope

- Build only what was asked: no extra features, no unrequested refactor, no speculative abstraction.
- Anything you notice beyond that goes in the report as a sentence, never into the diff.
- If two readings of the request produce different work, ask one question first.
- Reuse before you create. Search for an existing implementation, edit an existing file.

## Context

- Read narrowly. Grep for the symbol, then read that range. Never open a whole file to find one function.
- Delegate a search that would open more than a handful of files. Bring back the answer, not the contents.
- Never call a function, flag, or field you have not seen in this repo or its dependencies. Check first.

## Tests

- Every behavior change ships with a unit test in the same change. Skipping one requires a stated reason.
- The test must fail before the fix and pass after. If it passes before, it asserts nothing.
- Never weaken a test, silence a lint rule, or suppress a type error to make a check pass. Fix the cause, or stop and say why.
- Run only the tests affected by the change, quietest output, stop at the first failure. Do not run the full suite unless asked.

## Comments

- Default to none. Developers can read the code. Write one only when the code cannot carry the reason: a workaround, a constraint from outside the file, a deliberate deviation.
- Never a banner, never a restatement of the line below, never a docstring that repeats the signature.

## Skills

- `.claude/skills/` is the only directory that gets scanned. A skill anywhere else does not exist,
  and nothing warns you: the tool list is simply shorter than the folder. Install there.
- Declaring another path in `CLAUDE.md` does not fix it. A rule can tell an agent to read a file; it
  cannot register that file as an invokable skill, and it costs context in every session to say so.
- `skills-lock.json` records which of them are vendored from a public repo, with the source and a
  content hash. A skill absent from the lockfile is one of ours.

## Writing

Applies to code, comments, commits, docs, and chat.

- Never use an em dash. Use a comma, colon, or period.
- No filler openers, no closing offers, no restating the request back. No hype adjectives: comprehensive, robust, seamless, powerful.
- No emoji unless the user used one first. No "not just X, but Y".
