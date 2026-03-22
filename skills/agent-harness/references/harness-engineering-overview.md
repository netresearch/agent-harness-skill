# Harness Engineering Overview

## What is Harness Engineering?

Harness engineering is the discipline of designing repo-level infrastructure that makes AI coding agents reliable at scale. It represents a fundamental shift in how teams work with AI: from "humans write code, AI helps" to "humans design environments, agents execute."

The metaphor is straightforward. Modern AI models are powerful but directionless. A model with no constraints, no context, and no verification will produce plausible-looking output that may or may not solve the actual problem. The harness channels that raw capability into productive, verifiable work -- the same way a test harness channels code execution into observable, repeatable outcomes.

The harness is everything the model reads and everything that checks its output: AGENTS.md, architecture docs, CI workflows, git hooks, branch protection, linting rules, test suites, and the structural conventions that tie them together.

## The Four System Functions

OpenAI's harness engineering research (<https://openai.com/index/harness-engineering/>) identifies four system functions that a well-designed harness must provide. These are not sequential phases but concurrent, reinforcing layers.

### 1. Constrain

Define architectural boundaries and dependency rules. Tell the agent what it must not do, what patterns to follow, and where code belongs.

Constraining the solution space makes agents more productive, not less. An agent that knows "all database access goes through the repository layer" does not waste tokens exploring direct SQL in controllers. An agent that knows "this project uses conventional commits" does not invent its own commit message format.

Constraints live in AGENTS.md, ARCHITECTURE.md, linter configurations, and dependency rules.

### 2. Inform

Provide rich context so the agent understands the system it is working in. This includes architecture documentation, API specs, design decisions (ADRs), test expectations, and observability data.

The repository is the single source of truth. If the agent needs to know something to do its job, that information must be in the repo -- not in a team member's head, not in a Confluence page, not in a Slack thread. Context engineering is the practice of making relevant information discoverable and machine-readable within the repo structure.

Information lives in `docs/`, AGENTS.md references, inline code comments, and structured configuration files.

### 3. Verify

Test and validate agent output through mechanical means: linting, CI pipelines, structural tests, type checking, and harness consistency checks. Mechanical verification catches problems that human review misses or delays.

The key insight is that verification must be automatic and continuous. A verification step that requires a human to remember to run it is not verification -- it is a suggestion. CI workflows, pre-commit hooks, and required status checks provide genuine verification.

Verification lives in `.github/workflows/`, `.githooks/`, Makefile targets, and test suites.

### 4. Correct

Build feedback loops that let agents iterate until criteria are satisfied. When verification fails, the agent receives structured feedback (error messages, lint output, test failures) and tries again. Self-repair turns a single-shot interaction into a convergent loop.

Correction depends on clear, actionable error messages. A CI check that reports "harness verification failed" is less useful than one that reports "AGENTS.md references `docs/API.md` but that file does not exist." The more specific the feedback, the fewer iterations needed.

Correction lives in CI annotations, hook output, and structured error reporting from verification scripts.

## Complementary Perspectives

### Anthropic / Claude Code

Anthropic's agent development guidance (<https://docs.anthropic.com/en/docs/build-with-claude/agentic-systems>) emphasises:

- **TDD-first workflows** -- write tests before implementation so the agent has a concrete target.
- **Plan mode** -- agents propose a plan, get human approval, then execute. Separates thinking from doing.
- **Compact context transfer** -- keep instruction documents short and reference external files for detail. AGENTS.md as an index, not an encyclopedia.
- **Dedicated review steps** -- do not assume agent output is correct. Build review into the workflow.

### LangGraph and Durable Execution

LangGraph and similar frameworks focus on runtime durability:

- **Checkpointing** -- save agent state at each step so work survives failures.
- **Resume after failures** -- crashed agents pick up where they left off instead of restarting.
- **Human-in-the-loop** -- pause execution for human approval at defined points.

These runtime concerns are complementary to repo-level harness engineering. This skill focuses on the repo structure and verification layer. Runtime durability (tracing, evals, checkpointing) is a future extension.

### Industry Consensus

Across vendors and frameworks, several principles have converged:

- Large monolithic instruction files are counterproductive. Context must be structured and layered.
- Agents need external feedback loops. Self-assessment is unreliable; mechanical verification is essential.
- The repo itself is the best place to store agent instructions. External configuration drifts.
- Enforcement must work without the agent framework installed. Project-level mechanisms (CI, hooks, branch protection) outlive any specific tool.

## The Key Principle

> "The model is commodity; the harness is moat."
> -- OpenAI, Harness Engineering

OpenAI's research demonstrated this quantitatively. Improving the harness -- without changing the underlying model -- raised task performance from 52.8% to 66.5%. The same model, given better constraints, better context, better verification, and better correction loops, produced dramatically better results.

This means that investment in harness engineering compounds. Every improvement to documentation, CI checks, architectural constraints, and feedback loops benefits every agent interaction going forward, regardless of which model or framework is used.

## What This Skill Implements

The agent-harness skill implements the **repo-structure and verification layer** of harness engineering:

- **Constrain**: AGENTS.md with architectural rules, ARCHITECTURE.md with dependency boundaries.
- **Inform**: Structured `docs/` directory, index-format AGENTS.md with references to detailed documentation.
- **Verify**: `verify-harness.sh` script, CI workflow (`harness-verify.yml`), git hooks, maturity-level checkpoints.
- **Correct**: Actionable error messages from verification, bootstrap mode to create missing artefacts, structured output for CI annotations.

Runtime concerns (agent tracing, evaluation frameworks, durable execution, LLM observability) are outside the current scope and tracked as future extensions.

## Sources

- OpenAI Harness Engineering: <https://openai.com/index/harness-engineering/>
- Anthropic Agent Development: <https://docs.anthropic.com/en/docs/build-with-claude/agentic-systems>
- Claude Code SDK: <https://docs.claude.com/en/api/agent-sdk>
