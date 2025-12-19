#set document(
  title: "Thoughts of T1 diffential tests",
  author: "sh1marin",
  keywords: ("T1", "test"),
  date: datetime(year: 2025, month: 12, day: 19)
)

== Goal
I need a test framework for running multiple binary with simulator,
get the run output, use a way to determine the output is correct.

== Current Situation
I already have diff test CLI to compare Spike output and simulator output.
I also have a bunch Nix script to automate the build and tests.

== Problem
Nix has too much overhead: the reproducibility cames with a bunch
of bash, bwrap, chroot. It is not ideal to use Nix for thousands of tests.

== New Approach
Leverage the `pytest` utility.
=== Questions
- Is it better to have different test suites to have their own `pytest` script?
  - I prefer yes, it can split the script and help maintenance. Also some test
    suites might have unique simulator configuration or unique way to verify test
    case failure.
  - If we do this, how to share common commands.
  - If we decides to share common commands, how to customize the run commands for
    corner cases? Or create a new commands execution instead of customizing.
- Should we define the test case build script in the test script?
  - I prefer not, it makes the script complicated.
  - But an extra benefits is that we can leverage Ninja Python syntax to simplify the build system
    (current Makefile is already hard to understand and I do want to replace it).
  - If so, what is the best way to separate build and tests? Can it be made by two commands?
    And we also need a Nix derivation for it for caching purpose.
- How to configure the build? (E.g: Don't run floating point tests when simulator have no FP supports)
  - Environment variable? I prefer this, this could help Nix to transparently inject configuration.

== The Solution
Based on discussion with Gemini:

=== Concern 1: Execution Overhead & Velocity
*Solution:*
- *Shift the Runner:* Replace Nix test wrappers with `pytest`.
- *Role of Nix:* Downgrade Nix from "Task Executor" to "Environment Provider".
  Nix continues to supply the toolchain (GCC, Spike, Python), but Python
  handles the process spawning.
- *Benefit:* Removes the chroot penalty per test. Pytest runs in the host user
  space instantly.

=== Concern 2: Test Suite Organization & Maintenance
*Solution:*
- *Structure:* Use standard directory structures (`tests/isa/`,
  `tests/custom/`) rather than separate execution scripts.
- *Shared Logic:* Centralize the "Run & Diff" logic in a `conftest.py` fixture.
  This prevents code duplication.
- *Corner Cases:* Use `pytest` markers (e.g., `@pytest.mark.trace`) to inject
  custom flags into the shared fixture only for specific tests.

=== Concern 3: Build System Integration & Configuration
*Solution:*
- *Build-Test Decoupling:* Retain the `Makefile` for compilation (leveraging
  existing logic). Pytest treats the build artifacts (`*.elf`) as input data,
  not build targets.
- *Automation:* Use a `pytest` session-scoped fixture to trigger `make -j` once
  at the start.
- *Configuration:* Use Environment Variables (e.g., `RISCV_HAS_FP=0`). Pytest
  reads these at startup and automatically skips irrelevant tests using
  `pytest.mark.skip`, keeping the Nix/Shell integration clean.
