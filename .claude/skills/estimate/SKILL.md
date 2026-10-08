---
name: estimate
description: Use when asked how long something will take, to size a task, to give a story point, or whether work fits in a sprint. Separates the agent's own runtime from the wall clock to merged.
---

# Estimate

Give two numbers, never one.

## Agent time

What it actually costs to produce the change. Minutes, not human days.

Training data is full of human sprint estimates, so the pull toward "three days" is strong and wrong. Do not borrow it.

Say the real figure. If it is fifteen minutes, say fifteen minutes. Padding to sound safe destroys the only reason anyone asked.

## Wall clock to merged

Rarely the same number, and rarely driven by the code. Name which of these actually applies:

- A decision only a person can make, and nobody has made it
- Access, credentials, or an environment that does not exist yet
- Review latency
- Acceptance criteria that are not written down
- A dependency owned by someone else

If none of them apply, wall clock is close to agent time. Say so plainly instead of inflating it.

## Rules

- Give a range only when a named unknown causes it. "Two hours, or a day if that schema turns out to be shared" is useful. "Two hours to a day" is noise.
- If the task is vague enough that the number would be guesswork, say what you need to know instead of producing one.
- Never express agent work in story points. They measure human capacity, not this.
