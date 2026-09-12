# Comm-Log Send Reconciliation

## Xeno Data Analyst Take-Home Assignment

This repository reconciles Finance's `target_base` metric for merchant `501` during October 2026. The analysis uses a SQLite database containing campaign metadata and communication-log send events.

## Result at a glance

| Metric | Value |
| --- | ---: |
| Finance-reported `target_base` | **22** |
| Naive raw-row count | 30 |
| Reconciled `target_base` | **22** |
| Difference | **0** |

The Finance value is fully reconciled.

### Reconciled breakdown

| Campaign group | Reporting treatment | Count |
| --- | --- | ---: |
| Cart Recovery (`9001 -> 9002 -> 9003`) | Count each customer once across the retry chain | 10 |
| Flash Sale (`9101`) | Count every standalone send event | 7 |
| Wave 2 (`9201 -> 9202`) | Count each customer once across the retry chain | 5 |
| Pending branch (`9004`) | Excluded because approval is still pending | 0 |
| **Total `target_base`** |  | **22** |

## Business question

> For merchant `501`, which qualifying campaign sends in October 2026 should contribute to Finance's `target_base` metric?

The important part of this exercise is not only producing `22`. It is showing why the raw count is `30`, identifying the eight rows that should not contribute, and distinguishing retry duplicates from legitimate repeated standalone sends.

## Repository layout

```text
Xeno_Comm_Log_Assignment/
├── readme.md                  # This analysis and reconciliation report
├── analysis.sql               # Reproducible SQLite investigation queries
└── Data/
    ├── comm_log.db            # SQLite database used by the queries
    ├── campaign.csv           # Campaign table as CSV
    ├── communication_log.csv  # Communication log as CSV
    ├── generate_dataset.py    # Regenerates the synthetic database and CSVs
    └── README.md              # Data dictionary and loading instructions
```

## Quick start

### Requirements

- SQLite 3
- Python 3.9 or later (only needed to regenerate the sample data)

### Run the analysis

From the repository root, open the supplied database with SQLite:

```bash
sqlite3 Data/comm_log.db
```

Then run the complete query file:

```sql
.read analysis.sql
```

The final query returns the campaign-group counts and the reconciled total.

### Regenerate the supplied data

The generator writes both CSV files and `Data/comm_log.db`:

```bash
python Data/generate_dataset.py
```

## Data model

### `campaign`

One row represents one campaign or retry attempt.

| Column | Meaning |
| --- | --- |
| `id` | Unique campaign identifier |
| `merchant_id` | Merchant that owns the campaign |
| `parent_id` | Parent campaign when this row is a retry; `NULL` for an original campaign |
| `name` | Human-readable campaign name |
| `creation_status` | Campaign approval/lifecycle status |
| `processing_status` | Send-processing status |

### `communication_log`

One row represents one send attempt.

| Column | Meaning |
| --- | --- |
| `id` | Unique send-attempt identifier |
| `merchant_id` | Merchant associated with the send |
| `communication_id` | Campaign ID associated with the send |
| `customer_id` | Customer targeted by the send |
| `communication_type` | `'2'` means campaign communication |
| `delivery_status` | `900` means delivered; `1100` means soft failure |
| `sent_time` | Timestamp when the send occurred |
| `scheduled_time` | Timestamp when the send was scheduled |
| `credit_used` | Credits consumed by the send |
| `channel` | Delivery channel, `sms` in this dataset |

## Reporting rules

### 1. Campaign eligibility

A campaign contributes to official reporting only when both conditions are true:

```sql
creation_status IN ('approved', 'aborted', 'resumed', 'stopped')
AND processing_status = 'processed'
```

Campaign `9004` is `approval_awaiting`, so its four communication-log rows are excluded even though they already exist in the send table.

### 2. Retry chains are one underlying communication

`campaign.parent_id` identifies retry relationships:

```text
9001 (original)
└── 9002 (retry)
    └── 9003 (retry)
```

When a customer appears in more than one campaign in the same retry chain, that customer counts once. For example, customer `C3` appears in campaigns `9001`, `9002`, and `9003`, but contributes only one customer to `target_base`.

### 3. Standalone sends remain separate events

Campaign `9101` has no retry relationship. Customer `C20` appears twice under this campaign at different times, and both rows are legitimate standalone send events. Therefore, the campaign contributes `7`, not `6`.

## Investigation summary

### Step 1: Naive count

Counting every campaign send in scope produces `30` rows:

```sql
SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';
```

This is eight higher than Finance's `22`.

### Step 2: Inspect repeated customers

The campaign-level comparison shows the standalone duplicate and the retry groups:

| Campaign | Send rows | Distinct customers | Interpretation |
| ---: | ---: | ---: | --- |
| 9001 | 10 | 10 | Original Cart Recovery campaign |
| 9002 | 2 | 2 | Cart Recovery retry |
| 9003 | 1 | 1 | Cart Recovery retry |
| 9004 | 4 | 4 | Pending branch; excluded |
| 9101 | 7 | 6 | Standalone campaign; all 7 events count |
| 9201 | 5 | 5 | Original Wave 2 campaign |
| 9202 | 1 | 1 | Wave 2 retry |

### Step 3: Apply the reporting rules

- Exclude the four rows belonging to pending campaign `9004`.
- Deduplicate customers across the Cart Recovery retry chain: `10`.
- Count all seven Flash Sale standalone events: `7`.
- Deduplicate customers across the Wave 2 retry chain: `5`.

```text
10 + 7 + 5 = 22
```

## Final reconciliation

| Measure | Value |
| --- | ---: |
| Finance-reported `target_base` | 22 |
| Calculated `target_base` | 22 |
| Difference | 0 |

The complete investigation, including executable queries and expected outputs, is available in [`analysis.sql`](analysis.sql). The full schema and field definitions are in [`Data/README.md`](Data/README.md).

## Notes and assumptions

- The analysis is scoped to merchant `501`.
- The reporting period is `2026-10-01` through `2026-10-31`; the SQL uses an exclusive upper bound of `2026-11-01`.
- Only `communication_type = '2'` campaign communications are included.
- Retry-chain membership is determined from `campaign.parent_id`.
