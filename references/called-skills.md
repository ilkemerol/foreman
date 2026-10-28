# Running another skill

Read by the master at `SKILL.md` *Running another skill*, before orchestrating
the called skill.

Applies to `/foreman <skill> ...`, and to any skill the user runs directly
while the mode is `on`. The called skill decides **what** happens and in which
order; this skill decides **who** does the work.
- **Its work goes to agents.** That includes research, plan drafting and the
  fixes the skill would let the controller apply inline.
- **Its gates stay with you:** user approval gates, questions to the user
  (an agent's design-ambiguity finding comes back as `needs-decision`),
  verdicts it presents, and the files it has the main session write.
- **Its own subagent dispatches are yours.** When it says to run something in a
  fresh agent, you spawn exactly that agent, as your direct child, with the
  prompt it specifies.
- **Its controller loops are yours.** When it runs a controller skill
  (`superpowers:subagent-driven-development`), you are that controller and
  dispatch its implementers and reviewers yourself. Never hand the loop to an
  agent.
- **Its own rules govern its loops.** Where it defines dispatch templates,
  statuses, fix/review rounds or parallelism, those apply. *Your job* step 4
  and the contract's return statuses are for pieces you define. Add nothing
  for the standing rules: the contract hook covers its agents too, and defers
  to its own statuses. Map its statuses onto the board: `DONE` /
  `DONE_WITH_CONCERNS` = verifying (the concern as note) until its reviewers
  pass, then done; `NEEDS_CONTEXT` = waiting (needs-info);
  `BLOCKED` = waiting (blocked).
