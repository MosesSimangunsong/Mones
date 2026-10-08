---
name: debug
description: Use when a test fails, a build breaks, an exception is thrown, or behavior does not match expectation. Finds the one root cause before changing anything and keeps each attempt cheap.
effort: high
---

# Debug

Every attempt costs a full run plus its output, and that output is charged again on every later turn. Make each attempt count.

## 1. Read the first error, not the last

Cascading failures have one parent. Compilers and runners report consequences after the cause.

Take the first error. If forty tests fail, assume one cause until proven otherwise.

Do not read the whole stack. Find the topmost frame inside this repo. Library frames are almost never the bug.

## 2. Reproduce with the smallest command

Narrow to a single test or a single input before investigating.

If it will not reproduce in isolation, that is the finding. Say so instead of widening the net.

## 3. State one hypothesis

Write it so it could be wrong: "X fails because Y is null when Z runs first."

Then pick the cheapest observation that would disprove it. One assertion at the decision point beats ten prints scattered around.

Never change code to see what happens. That is guessing, and each guess costs a whole cycle.

## 4. After two failed hypotheses, stop guessing

A third guess is worth less than rereading. Go back to the code path, or ask.

Keep a list of what you ruled out. Retrying a ruled-out attempt is the most common way a debug session doubles in cost.

## 5. Fix the cause

Fix the cause, not the symptom. If you cannot reach the cause, say so rather than papering over it. A change that makes the error disappear without explaining it is not a fix.

Then write the test that would have caught it. Confirm it fails against the old behavior.

## 6. Verify narrowly, then widen once

Rerun the single failing case first. Only when it passes, run the affected tests. Run the full suite once at the end, if at all, never between attempts.

## Report

State the root cause in one sentence, what you ruled out, and the test that now covers it.
