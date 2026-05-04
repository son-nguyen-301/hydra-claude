---
name: tdd
description: "Used internally by coding agents (sprinter, builder, architect). Applies Test Driven Development discipline: write a failing test first, then the minimum code to pass it, then refactor. Use this skill only when the user explicitly asks for TDD, says 'write tests first', 'red-green-refactor', 'test-driven', or 'start with a failing test'. Do not apply automatically. Framework-agnostic."
---

# TDD Skill

This skill enforces TDD discipline when explicitly requested. It layers on top of any active framework or coding context — the context says *what* to write and *how*, this skill says *in what order*.

## The only valid cycle

```
RED    → write the smallest failing test describing the next behaviour
GREEN  → write the minimum code to make it pass — nothing more
REFACTOR → clean up while tests stay green
```

Repeat per behaviour until the feature is complete.

## Output format

Every task using this skill produces a step-by-step narration of the RED→GREEN→REFACTOR cycle. For each behaviour:

1. **RED** — show the test, explain what it asserts and why it fails right now
2. **GREEN** — show the minimum implementation that makes it pass; explain why nothing extra is written yet
3. **REFACTOR** — show the cleaned-up version if there is something to improve; confirm tests still pass

Then move to the next behaviour and repeat. Do not skip ahead and show the final code without the cycle — the narration is the output.

## Before writing any test

Break the feature into observable behaviours first. Ask or infer:

- What does the user or system experience for each behaviour? (Not the implementation — the outcome)
- What is the smallest first test that would fail right now?
- What level of test is right? Unit (pure logic) → Component/Integration (flow across units). Pick the lowest level that gives meaningful confidence.

Write out the behaviour list before starting the first RED phase.

## Writing the failing test (RED)

A good test describes one behaviour in plain language and targets the interface — what goes in, what comes out, what renders — not internal state.

```ts
// Tests what the user sees — survives refactoring
it('displays a validation error when email is empty', async () => {
  // ... renders the component, triggers submit, asserts the error text
  expect(emailError.text()).toBe('Email is required')
})

// Tests internal state — breaks if the variable is renamed
it('sets hasError to true', () => {
  expect(component.hasError).toBe(true)  // avoid
})
```

Confirm the test fails before writing any implementation. A test that passes with no implementation is either wrong or testing something that already existed.

## Writing the minimum implementation (GREEN)

Write only enough to make the current test pass. Hardcoding a return value is acceptable in the green phase — the next test forces generalisation. Writing extra logic "while you're in there" skips tests that should have demanded it.

```ts
// First test: greet('Alice') returns 'Hello, Alice'
// Minimum green:
function greet(_name: string) {
  return 'Hello, Alice'  // hardcoded — legitimate at this stage
}

// Second test forces greet('Bob') to return 'Hello, Bob'
// Now generalise:
function greet(name: string) {
  return `Hello, ${name}`
}
```

## Refactoring (REFACTOR)

Refactor only when all tests are green. Extract duplication, improve naming, tighten types. Run tests after every change — if they go red, the refactor introduced a regression.

## Naming tests

Tests are documentation. Names should read as sentences describing the product's behaviour.

```ts
// Reads like a spec
describe('LoginForm', () => {
  describe('when submitted with an empty email', () => {
    it('displays a required field error')
    it('does not call the auth API')
  })
  describe('when credentials are invalid', () => {
    it('shows the error message from the server')
    it('clears the password field')
  })
})
```

## Warning signs — stop and address before continuing

- Implementation written before a failing test → write the test first
- A new test passes immediately with no implementation → the test is wrong
- Tests depend on each other's order → make each test fully self-contained
- Test description contains "and" → likely two behaviours; split it
- Test is longer than ~15 lines → probably testing too many things
- You are mocking the thing under test → you are testing the mock, not the code
