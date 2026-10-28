# One-shot runs

Read by the master when `/foreman` gets a skill with its arguments or a task
(`SKILL.md` *Mode from the arguments*), before acting on it.

| Arguments | Do this |
|-----------|---------|
| First word exactly matches a skill in your available-skills list (`plugin:name`, or a unique bare name, with or without `/`) and the rest reads as its arguments, e.g. `my-skill 123` | One-shot: `foreman-state.sh task` (if the mode was `off`, then offer the live view - see *foreman-vision*), invoke that skill via the Skill tool with the remaining words as its args, and orchestrate it (see *Running another skill*). |
| Anything else - including an ordinary verb that happens to be a skill name (`run`, `loop`, `design`, `schedule`, `simplify`) followed by a sentence | One-shot: `foreman-state.sh task` (if the mode was `off`, then offer the live view - see *foreman-vision*), orchestrate that text as the task. If unsure whether the first word means a skill, ask. |

**A one-shot stays open across gates and user turns.** It ends only when the
called skill has no step left, the task is done, or the user drops it.
Another `/foreman` task or skill while a run is open joins that run, which
ends when all of its tasks have. Close in this
order: paste `show`, then `foreman-state.sh end`, then the *foreman-vision* stop
or hide question. `end` never removes an `on` flag.
