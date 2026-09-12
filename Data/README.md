# Comm-Log Reconciliation — Data Dictionary

This is the raw data for the take-home in `ASSIGNMENT.md`. Everything you need is either
in the schema below or discoverable by querying the data itself.

## Loading the data

`data/comm_log.db` is a SQLite database with two tables (also available as
`data/campaign.csv` and `data/communication_log.csv` if you prefer a different tool).

```
sqlite3 data/comm_log.db
.tables
.schema campaign
.schema communication_log
```

## Table: `campaign`

One row per campaign. A campaign can be a **retry** of an earlier campaign — this is
how the system represents "we re-sent to customers who didn't respond/failed on a
previous attempt."

| Column | Type | Meaning |
|---|---|---|
| `id` | int | Campaign id. |
| `merchant_id` | int | Owning merchant. |
| `parent_id` | int, nullable | If set, this campaign is a retry attempt of `parent_id`. NULL means this campaign was not created as a retry of anything (it may still have its own retries pointing at it). |
| `name` | text | Human-readable label. |
| `creation_status` | text | Lifecycle state of the campaign's *creation/approval* workflow. Values seen in this dataset: `approved`, `approval_awaiting`. Other real values include `aborted`, `resumed`, `stopped` (all of these, plus `approved`, are considered finalized/live for reporting purposes). `approval_awaiting` means the campaign has not cleared approval yet. |
| `processing_status` | text | Lifecycle state of the campaign's *send* workflow. `processed` means the send pipeline has finished running for this campaign. |

**A campaign is included in official reporting only once both its creation workflow
has cleared (`creation_status` in the finalized set above) and its processing has
completed (`processing_status = 'processed'`).** A campaign still `approval_awaiting`
has not been signed off and does not count toward reported sends, even if
`communication_log` rows already exist for it (the send pipeline can run ahead of
approval bookkeeping catching up).

## Table: `communication_log`

One row per individual send attempt.

| Column | Type | Meaning |
|---|---|---|
| `id` | int | Row id (one per send attempt). |
| `merchant_id` | int | Owning merchant. |
| `communication_id` | int | FK to `campaign.id` — which campaign this attempt belongs to. |
| `customer_id` | text | Customer targeted. |
| `communication_type` | text | `'2'` = Campaign (the only type in this dataset). |
| `delivery_status` | int | `900` = delivered successfully. `1100` = failed (soft failure — the customer may be retried via a new campaign row, or genuinely re-targeted later). |
| `sent_time` / `scheduled_time` | timestamp | When the send happened / was scheduled. |
| `credit_used` | int | Billing credits consumed by this attempt. |
| `channel` | text | Send channel (`sms` throughout this dataset). |

**A customer can legitimately appear more than once against the same `communication_id`.**
This happens when a campaign is independently re-run or a customer is re-targeted after
falling back into the audience — it is a separate event from a *retry*, which always
creates a **new** campaign row (`campaign.parent_id` pointing back at the original).

## Retry chains

If campaign B has `parent_id = A`, B represents "the same underlying communication,
re-attempted." A chain can be more than two levels deep (A -> B -> C). A customer who
was sent A (and failed), then B (and failed), then C (and delivered) was targeted by
the *same underlying communication* three times — not three independent communications.

## What "reporting" considers a qualifying send

Finance's `target_base` metric answers: **for a given underlying communication (a
campaign plus every retry chained off it), how many distinct customers were reached?**
A customer who took several attempts within one retry chain to finally get delivered
still counts once. A campaign with no retry chain at all (no other campaign points at
it, and it points at nothing) is a standalone communication — every send under it is
its own event, whether or not the same customer appears twice.

## Scope for this exercise

All data is for `merchant_id = 501`, sends in October 2026, `communication_type = '2'`
(Campaign) only.
