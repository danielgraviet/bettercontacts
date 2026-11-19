# Testing at BetterContacts

Our test suite follows the unit testing chapter of
*[Software Engineering at Google](https://abseil.io/resources/swe-book/html/ch12.html)*
(ch. 12, "Unit Testing"). This document maps each principle from that chapter
to a concrete convention in this repo, so the philosophy survives the people
who wrote it.

Run everything with `make test` (same command CI runs).

---

## The 80/20 rule

Google's guidance: roughly **80% unit tests, 20% broader-scoped tests**, because
unit tests are fast, deterministic, and easy to diagnose when they fail.

Where we stand:

| Layer | Tests | Scope |
|---|---|---|
| `DomainTests` | 61 tests | Unit — pure logic, no I/O, milliseconds each |
| `BetterContactsTests` | 5 tests | Unit — ViewModel with a fake repository |
| `BetterContactsUITests` | 1 test | Smoke — app launches and renders real data |

The broad tests exist to catch wiring mistakes the units can't see (target
membership, storyboard/launch settings, the composition root). They do not
re-test domain behavior.

## Test via public APIs, not implementation details

Every `DomainTests` file does a plain `import Domain` — **no `@testable`**.
If a test needs `@testable` to reach something, that thing is an implementation
detail and the test would be brittle by construction.

The one exception is `BetterContactsTests`, which uses `@testable import
BetterContacts` to reach the ViewModel. That's access-control pragmatics (the
test bundle is outside the app module), not a license: those tests still only
touch the ViewModel's public surface — `load`, `setSearchText`,
`logInteraction`, and observable state.

The practical payoff: internal refactors (renaming a private helper, splitting
an engine, changing a data structure) never touch the test suite. Only *behavior
changes* do.

## Test state, not interactions

From the chapter: state testing observes what the system looks like after you
act on it; interaction testing verifies *how* it acted on collaborators — and
is brittle, because refactoring an implementation (say, writing to the store
through a different path) breaks interaction tests without breaking users.

Concretely:

- `FakeContactRepository` is a **fake**, not a mock: plain stored state, no call
  recording, no `verify()` steps.
- We assert on *outcomes*: `viewModel.overdueTouchpointReminders` became empty
  after logging an interaction. We don't assert that a save method was called
  in a particular order.
- The recorded `recordedInteractions` array exists as persisted state we assert
  against directly (`#expect(repository.recordedInteractions.first?.kind ==
  .metInPerson)`) — not as a sequence of expected calls.

No mocking frameworks are used anywhere in the repo.

## Name tests after the behavior being tested

A failing test's name is the first thing an engineer reads. Names read as
sentences about the system under test:

```swift
@Test("is due exactly on the day the cadence elapses")
func isDueExactlyOnTheDayTheCadenceElapses()

@Test("celebrates February 29 birthdays on February 28 in non-leap years")
func celebratesFebruaryTwentyNineOnFebruaryTwentyEightInNonLeapYears()

@Test("answers 'who did I meet this week?' with only this week's meetings")
func answersWhoDidIMeetThisWeekWithOnlyThisWeeksMeetings()
```

If you need the word "and" in a test name, you're probably testing two
behaviors — write two tests.

## Structure tests to emphasize behaviors: given, when, then

Every test body is three sections, in order, with the comments explicit:

```swift
@Test("keeps only close-circle contacts when onlyCloseCircle is on")
func keepsOnlyCloseCircleContactsWhenOnlyCloseCircleIsOn() {
    // Given one close-circle contact and one regular contact
    let inner = makeContact(id: "inner", firstName: "Ada", isCloseCircle: true)
    let outer = makeContact(id: "outer", firstName: "Grace", isCloseCircle: false)

    // When filtering to the close circle only
    let result = ContactFilterEngine.apply(ContactFilter(onlyCloseCircle: true), to: [outer, inner])

    // Then only the close-circle contact remains
    #expect(result == [inner])
}
```

One "when" and one "then" per test, with a single exception allowed for
multi-step flows. Assertions never interleave with actions.

## No logic in tests

Straight-line code only. If a test contains a loop, a conditional, or string
assembly that mirrors production code, the test can hide bugs exactly like the
one it's supposed to catch. Precompute expected values as literals:

```swift
// Then the date range is that Monday through Sunday
let expected = DateInterval(start: testDate(2001, 1, 1, hour: 0), end: testDate(2001, 1, 8, hour: 0))
#expect(query.dateRange == expected)
```

## DAMP, not DRY

Test code favors **Descriptive And Meaningful Phrases** over aggressive
de-duplication. The shared `makeContact()` builder gives every test sane
defaults, and each test overrides only the fields it cares about — the exact
`newContact(firstName:)` pattern from the chapter:

```swift
makeContact(id: "overdue", firstName: "Ada", isCloseCircle: true,
            lastInteractionDate: testDate(2000, 12, 1))
```

What we deliberately *don't* abstract away: test data. Two contacts built
slightly differently in two tests is fine — completeness beats conciseness.
The builder exists so tests are *concise about what varies*, not so they're
short at any cost.

## Determinism is non-negotiable

Every test that touches time uses the injected fixtures in
`DomainTestSupport`:

- `referenceNow` — 2001-01-01 00:00:00 UTC, a Monday, so calendar boundaries are obvious
- `testCalendar` — Gregorian, UTC, weeks starting Monday: no DST, no locale surprises
- `testDate(2001, 1, 5)` — dates built at noon UTC, away from midnight edges

Nothing reads `Date()`, `Calendar.current`, or `Locale.current` inside a test.
The engines accept `now`, `calendar`, and clocks as parameters — that's not just
testability, it's the design lesson the chapter opens with: *dependencies you
can control are dependencies you can trust*.

## Strive for unchanging tests

The ideal test never changes unless the *requirements* change. That constrains
how we encode contracts — ambiguous edges get a documented decision and a test
named after it, so the day someone "fixes" the behavior, a test fails with a
name that explains what world broke:

- A touchpoint is due **on** the day its cadence elapses (`>=`, not `>`)
- A never-contacted contact counts as stale **from the day it was added**
- Feb 29 birthdays are celebrated **on Feb 28** in non-leap years
- Contacts with no birthday **sort last** in "Next birthday"
- Filtering by "met this week" **excludes** people never logged as met
- Sorting ties **always** break alphabetically — no unstable orders, ever
- Semantic search **overrides** the manual sort while free text is present

## Clear failure messages

Assertions use Swift Testing's `#expect`, which reports expected vs. actual
inline (`#expect(urgency.daysOverdue == 36)` fails with both values shown).
`XCTAssert`-style boolean-only assertions (`#expect(result == true)`) are
avoided because they can't say *why*.

## What we deliberately don't unit test

Following the chapter's reasoning that tests must pay for themselves:

- `LiveContactProvider` (CNContactStore) — a system SDK boundary; exercised by
  the UI smoke test and manual runs, not mocked
- `AnnotationStore` (SwiftData) — Apple's framework, already tested by Apple;
  exercised end-to-end instead
- `NotificationReminderScheduler` (UserNotifications) — same boundary logic

Wrapping these in mocks would be interaction testing at its least valuable:
slow to write, brittle to maintain, and blind to the real failure modes.
