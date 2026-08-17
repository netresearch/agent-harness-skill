# retro-skill spec — moved

The retro-skill specification was written in this repository in May 2026,
before `netresearch/retro-skill` existed. It moved with the implementation and
is maintained there:

**[netresearch/retro-skill — `docs/specs/retro-skill.md`](https://github.com/netresearch/retro-skill/blob/main/docs/specs/retro-skill.md)**

The copy that used to sit here was the pre-July-2026 version. It still claimed
to be the canonical contract while describing six destinations instead of the
current seven, no authority axis, Coach as a live data source, and
`~/.claude/projects/<slug>/memory/feedback_<slug>.md` as the target for
personal learnings — the cwd-scoped location retro now forbids as a
destination. It was removed rather than patched: one spec, one owner, and a
second copy only drifts again.

What this repository owns about the integration is in
[`skills/agent-harness/references/skill-integration-map.md`](../../skills/agent-harness/references/skill-integration-map.md)
(section 12): which artefacts the harness expects in a retro-active repo, and
which checkpoints verify them. The historical decision record stays in
[`docs/plans/2026-05-11-retro-skill.md`](../plans/2026-05-11-retro-skill.md).
