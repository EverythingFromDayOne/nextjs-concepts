# Queue runbook — sessions 13–16

Four sessions are ready. This is what to run, in what order, and — more usefully — **what each result would change**, so you can run several without waiting on me between them.

Bring a report back mid-queue only when it hits one of the "stop and tell me" rows.

---

## Order

Any order works; none of the four depends on another. But this sequence front-loads the results that unblock the most writing:

| # | Session | Why this position |
| --- | --- | --- |
| 1 | **15** — tags and invalidation | Unblocks article 12, recipe #3, and article 21. Highest downstream value. |
| 2 | **13** — `use cache` directive | Unblocks article 13 (remote caches). Tests two claims already shipped. |
| 3 | **14** — cache lifetimes | Self-contained. One experiment waits ~2 minutes. |
| 4 | **16** — recipe #1 | Longest run; many rebuilds. Good one to leave going. |

After all four, Wave 2 is half-landed and I can write the remaining three articles against measurements rather than assumptions.

---

## What to watch for, per session

### Session 15 — tags

**The one that could dissolve an article.** If `updateTag` and `revalidateTag` behave identically in the response to the action that called them, article 11's entire organising distinction is wrong.

| Result | What it changes | Stop? |
| --- | --- | --- |
| The two functions differ as described | Article 11 stands | No |
| **They behave identically** | Article 11 needs rewriting around whatever the real distinction is | **Yes** |
| Inner-tag invalidation doesn't refresh an outer scope | Becomes a Common mistake in 11 and a section in article 12 | No |
| `updateTag` works outside a Server Action | Corrects articles 6 and 9 | **Yes** |

Check before trusting any of it: **was the cached entry warm before the write?** A cold miss makes both functions look identical.

### Session 13 — the directive

Two claims of mine from session 3 are on trial.

| Result | What it changes | Stop? |
| --- | --- | --- |
| Reversed arrays share an entry | My `lib/catalog.ts` comment is wrong → article 1 corrects on rebuild | **Yes** |
| Entries survive a rebuild | Articles 1, 6, and 9 all overclaim about deploys | **Yes** |
| A directive position doesn't work as described | Article 9's opening table is wrong | **Yes** |

Experiment B has a confound the prompt names: a module counter resets with the process. Make sure the report says how "cold cache" was distinguished from "counter reset."

### Session 14 — lifetimes

| Result | What it changes | Stop? |
| --- | --- | --- |
| Clocks separate as described | Article 10 stands | No |
| **No timing difference past `expire`** | Articles 6, 9, and 10 all describe a blocking path that doesn't exist | **Yes** |
| Omitting `cacheLife` doesn't throw | The "always call `cacheLife`" convention is advice, not a guardrail — weakens 6, 9, 10 | **Yes** |
| Custom profile names are typed | Small addition to article 10's patterns | No |

If the artificial delay is too small to separate signal from noise, the right answer is a bigger delay, not a hedged number.

### Session 16 — recipe #1

| Result | What it changes | Stop? |
| --- | --- | --- |
| Cascade order differs from the recipe's staging | Restage the walkthrough — cheap, and the real order is the point | No |
| The intermediate state **isn't** worse than pre-upgrade | The recipe's central warning is wrong | **Yes** |
| `dynamic = 'force-dynamic'` is accepted rather than an error | Contradicts articles 1, 6, and the ledger | **Yes** |
| Codemod behaves differently than the roadmap notes | Update the roadmap note | No |

---

## Standing checks, every session

- **Gates green**, including the demo build and tests.
- **`unsourced-other` at or near zero.** Growth means a hand-written fence slipped past the draft exemption.
- **Link buckets**: hard failures must be zero. Planned-forward rising during active work is normal — it falls as articles land.
- **Scratch routes removed.** Every session here creates probes.
- **Anything contradicting a shipped article named explicitly.** That instruction is in all four prompts and it's the thing that's caught every correction so far.

---

## After the queue

Wave 2 will be 3 of 6 landed. Remaining, and what each waits on:

- **Article 12** — `composition-and-cache-boundaries` ← session 15's propagation result
- **Article 13** — `remote-caches-and-durability` ← session 13's build-ID result, plus session 11's finding that `'use cache: private'` gives no server-side caching
- **Article 14** — `the-other-cache-layers` ← both of the above

Also unblocked by session 15: **recipe #3** (`mutations/action-succeeded-ui-didnt-update`), which is the mutation-side view of the same measurement.

Still open and needing you rather than a session: **roadmap §7's remaining invented decisions.** §7.2 is resolved; the checklist has thirteen others unchecked since revision 2. None blocks Wave 2, but §7.4 (the 47-article count and wave assignment) is worth confirming before Wave 3 starts, since that's where the article list gets long.
