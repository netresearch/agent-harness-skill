# Agent-First Architecture

Design choices that make a repository legible and predictable for AI coding agents. These complement the four system functions (constrain, inform, verify, correct) by addressing what the agent sees when it runs the system, not just when it reads about it.

Source: OpenAI Harness Engineering (<https://openai.com/index/harness-engineering/>).

## Application Legibility

For an agent to validate its own changes, it must be able to inspect the running system. Without this, the agent is flying blind and depends entirely on test-suite proxies for correctness.

Three legibility primitives:

- **Isolated runtime per worktree.** Every git worktree should be able to spin up an isolated instance of the product on a unique port/socket so the agent's branch and the agent's running system are tied together. Tools: ddev with project-scoped names, docker compose with project-name overrides, devcontainers per worktree.
- **Visual inspection.** Agents inspect rendered output, not just code. Wire up Chrome DevTools Protocol or Playwright so the agent can request DOM snapshots and screenshots. Frontend changes that look correct in JSX may render broken; the harness should let the agent see that.
- **Queryable observability.** Logs, metrics, and traces should be locally accessible to the agent in structured form. `docker compose logs --since=30s --no-color` is enough for many cases. Without observability, agents debug by intuition.

These belong in the project's dev-environment scripts and Makefile/composer/npm targets, surfaced through AGENTS.md so the agent knows they exist.

## Layered Dependency Model

OpenAI enforces a strict layered architecture. Their canonical stack:

```
Types -> Config -> Repo -> Service -> Runtime -> UI
```

The specific layer names are not the point; the point is that the dependency graph is explicit, declared in code, and enforced by tooling. Agents do not absorb architecture from culture -- they follow rules that produce errors.

Custom linters check imports against the layer rule -- a UI module cannot import directly from Runtime, a Service module cannot import from UI, and so on. When a violation occurs, the linter must produce an actionable error message aimed at the agent: name the file, name the rule, name the fix.

Compare:

- ❌ "Architectural violation in `component.tsx`"
- ✅ "`component.tsx` (UI layer) imports from `src/runtime/cache.ts` (Runtime layer); UI must call Runtime through a Service. See `docs/ARCHITECTURE.md#layer-rules`."

Recommended starting points for repos using this skill:

1. Document the layer model in `docs/ARCHITECTURE.md` with a dependency diagram.
2. Add a custom linter rule (eslint-plugin-boundaries, deptrac for PHP, or a small AST script) that enforces it.
3. Make the rule a hard CI gate, not advisory.

## Agent-First Technology Choices

Prefer composable, boring technologies with stable APIs over cutting-edge libraries with opaque internals.

Why: agents reason from context. A library with predictable, well-documented behaviour fits in the context window and yields correct code. A library that "does magic" forces the agent to either guess or re-read its source -- both of which fail at scale.

Practical implications:

- Use libraries with stable, well-documented APIs over those that change frequently or rely on convention-over-configuration.
- When an external library proves consistently unpredictable for agents (mocks fail; generated code looks plausible but is wrong; the agent invents APIs that do not exist), consider reimplementing the slice you actually need in-repo. Repo code is fully legible to the agent; library code is not.
- Boring beats clever for harnessed repos. The cost of a less-clever library is paid once; the cost of an opaque library is paid on every agent interaction.

This is not a license to NIH everything. It is a deliberate trade-off: pay implementation cost once to get reliable agent behaviour forever after.

## How These Relate to the Four Functions

| Concept | Function | Where it lives |
|---|---|---|
| Application legibility | Inform + Verify | Dev-environment scripts, observability tooling, Makefile targets |
| Layered dependency model | Constrain | `docs/ARCHITECTURE.md` + custom linter |
| Boring technology choices | Constrain | Dependency policy in AGENTS.md, ADRs documenting reimplementation decisions |

These reinforce one another: a layered architecture composed of opaque libraries is no architecture at all, and legibility without constraint just shows the agent more chaos.
