# Comm-Log Send Reconciliation

### Xeno Data Analyst Take-Home Assignment · 2026

> **Reproducing Finance's `target_base` for Merchant 501 — October 2026**

---

## 📌 Executive Summary

This project investigates and reconciles Finance's reported **`target_base = 22`** for **merchant `501`** during **October 2026**.

A straightforward count of campaign communication records produces **30 rows**, which does not match Finance's reported value.

Instead of forcing the query to return `22`, the analysis investigates the raw data and identifies the business rules responsible for the difference:

* **4 rows** belong to campaign `9004`, which is still `approval_awaiting` and therefore not eligible.
* Campaigns `9001 → 9002 → 9003` form a **retry chain**, so repeated customers are counted once.
* Campaign `9101` is a **standalone campaign**, so all 7 send events are valid, including two separate sends to `C20`.
* Campaigns `9201 → 9202` form another **retry chain**, so repeated customers are counted once.

### Final result

```text
Naive raw communication rows     = 30
Pending campaign rows excluded   =  4

Cart Recovery retry chain        = 10
Flash Sale standalone            =  7
Wave 2 retry chain               =  5
                                   ---
Final target_base                = 22
```

**Finance target_base = 22**
**Calculated target_base = 22**
**Difference = 0**

> ✅ **Finance's `target_base` is successfully reconciled.**

---

## 📊 Result at a Glance

| Metric                         |                       Value |
| ------------------------------ | --------------------------: |
| Merchant                       |                     **501** |
| Reporting period               |            **October 2026** |
| Finance-reported `target_base` |                      **22** |
| Naive raw-row count            |                      **30** |
| Reconciled `target_base`       |                      **22** |
| Difference                     |                       **0** |
| Status                         | **Successfully Reconciled** |

---

## 🔍 Reconciled Breakdown

| Campaign Group          | Campaigns            | Reporting Treatment                         |  Count |
| ----------------------- | -------------------- | ------------------------------------------- | -----: |
| Cart Recovery           | `9001 → 9002 → 9003` | Count each customer once across retry chain | **10** |
| Flash Sale              | `9101`               | Count every standalone send event           |  **7** |
| Wave 2                  | `9201 → 9202`        | Count each customer once across retry chain |  **5** |
| Pending branch          | `9004`               | Excluded because approval is pending        |  **0** |
| **Total `target_base`** |                      |                                             | **22** |

---

# 🎯 Business Question

> **For merchant `501`, which qualifying campaign sends in October 2026 should contribute to Finance's `target_base` metric?**

The objective is not simply to produce the number `22`.

The analysis starts from the raw communication data, establishes the naive count, investigates the mismatch, identifies campaign eligibility and retry relationships, and then applies the appropriate reporting treatment.

---

# 🧠 Investigation Approach

The analysis follows a reproducible investigation workflow:

```text
Raw SQLite Database
        │
        ▼
Inspect Tables & Schemas
        │
        ▼
Inspect Campaign Relationships
        │
        ▼
Inspect Communication Logs
        │
        ▼
Calculate Naive Count
        │
        ▼
30 Raw Rows
        │
        ▼
Check Campaign Eligibility
        │
        ▼
Exclude Pending Campaign 9004
        │
        ▼
26 Eligible Rows
        │
        ├───────────────┐
        ▼               ▼
 Retry Chains      Standalone
        │               │
        ▼               ▼
Deduplicate       Keep Events
 Customers          Separate
        │               │
        └───────┬───────┘
                ▼
       Final target_base
                │
                ▼
               22
```

---

# 📁 Repository Structure

```text
Xeno_Comm_Log_Assignment/
│
├── README.md
├── analysis.sql
│
└── Data/
    ├── comm_log.db
    ├── campaign.csv
    ├── communication_log.csv
    ├── generate_dataset.py
    └── README.md
```

### Files

| File                         | Purpose                                                         |
| ---------------------------- | --------------------------------------------------------------- |
| `README.md`                  | Business explanation, investigation, reconciliation and results |
| `analysis.sql`               | Reproducible SQLite investigation queries                       |
| `Data/comm_log.db`           | SQLite database used for the analysis                           |
| `Data/campaign.csv`          | Campaign data in CSV format                                     |
| `Data/communication_log.csv` | Communication-log data in CSV format                            |
| `Data/generate_dataset.py`   | Script for regenerating the supplied dataset                    |
| `Data/README.md`             | Data dictionary and dataset information                         |

---

# 🚀 Quick Start

## Requirements

* SQLite 3
* Python 3.9+ *(only required if regenerating the dataset)*

## 1. Clone the repository

```bash
git clone <your-repository-url>
cd Xeno_Comm_Log_Assignment
```

## 2. Open the SQLite database

From the repository root:

```bash
sqlite3 Data/comm_log.db
```

## 3. Run the complete analysis

Inside SQLite:

```sql
.read analysis.sql
```

The SQL file contains the investigation queries and the final reconciliation query.

---

# 🗄️ Data Model

The analysis uses two main tables:

```text
campaign
    │
    │ campaign.id = communication_log.communication_id
    ▼
communication_log
```

---

## `campaign`

One row represents one campaign or retry attempt.

| Column              | Meaning                              | Reconciliation Relevance             |
| ------------------- | ------------------------------------ | ------------------------------------ |
| `id`                | Unique campaign identifier           | Links campaign to communication logs |
| `merchant_id`       | Merchant that owns the campaign      | Restricts analysis to merchant `501` |
| `parent_id`         | Parent campaign when this is a retry | Identifies retry relationships       |
| `name`              | Human-readable campaign name         | Helps understand campaign purpose    |
| `creation_status`   | Campaign lifecycle / approval status | Determines campaign eligibility      |
| `processing_status` | Processing state                     | Must be `processed` for reporting    |

---

## `communication_log`

One row represents one send attempt.

| Column               | Meaning                           | Reconciliation Relevance                |
| -------------------- | --------------------------------- | --------------------------------------- |
| `id`                 | Unique send-attempt identifier    | Identifies an individual send row       |
| `merchant_id`        | Merchant associated with the send | Restricts analysis to merchant `501`    |
| `communication_id`   | Campaign associated with the send | Joins to `campaign`                     |
| `customer_id`        | Customer targeted by the send     | Used for retry-chain deduplication      |
| `communication_type` | Communication category            | `'2'` represents campaign communication |
| `delivery_status`    | Delivery result                   | `900` delivered, `1100` soft failure    |
| `sent_time`          | Actual send timestamp             | Defines reporting period                |
| `scheduled_time`     | Scheduled send timestamp          | Contextual field                        |
| `credit_used`        | Credits consumed                  | Contextual field                        |
| `channel`            | Delivery channel                  | `sms` in this dataset                   |

---

# 📋 Reporting Rules

The reconciliation depends on three important business rules.

---

## 1️⃣ Campaign Eligibility

A campaign is eligible for official reporting only when **both** conditions are satisfied:

```sql
creation_status IN (
    'approved',
    'aborted',
    'resumed',
    'stopped'
)
AND processing_status = 'processed'
```

Campaign `9004` has:

```text
creation_status = approval_awaiting
processing_status = processed
```

Therefore, it is **not eligible**.

Campaign `9004` contains **4 communication-log rows**, but those rows do not contribute to Finance's `target_base`.

---

## 2️⃣ Retry Chains Count Customers Once

The `parent_id` column identifies relationships between original campaigns and retries.

### Cart Recovery

```text
9001
  │
  ▼
9002
  │
  ▼
9003
```

These campaigns represent one retry chain.

For example:

```text
C3 → 9001
C3 → 9002
C3 → 9003
```

Although there are three communication rows, they belong to the same underlying retry journey.

Therefore:

```text
C3 counts as 1
```

The Cart Recovery chain contributes:

```text
10
```

---

## 3️⃣ Standalone Sends Remain Separate Events

Campaign `9101` has no parent campaign:

```text
9101
```

Therefore, it is treated as a standalone campaign.

Customer `C20` appears twice:

```text
9101 | C20 | 2026-10-10
9101 | C20 | 2026-10-20
```

These are separate send events within a standalone campaign.

Therefore, both events count.

```text
Flash Sale = 7
```

This is why a global:

```sql
COUNT(DISTINCT customer_id)
```

would be incorrect for the entire dataset.

It would reduce Flash Sale from:

```text
7 events
```

to:

```text
6 customers
```

and incorrectly remove one legitimate send event.

---

# 🔎 Investigation

## Step 1 — Establish the Naive Baseline

The first query counts every campaign communication row for merchant `501` during October 2026:

```sql
SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';
```

### Result

```text
30
```

Finance reports:

```text
22
```

Therefore:

```text
30 - 22 = 8
```

There is an 8-unit difference that needs to be explained.

The important analytical step is to **investigate the difference rather than force the query to return 22**.

---

# Step 2 — Compare Send Rows and Distinct Customers

The next query compares raw send rows with distinct customers for each campaign:

```sql
SELECT
    communication_id,
    COUNT(*) AS send_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01'
GROUP BY communication_id
ORDER BY communication_id;
```

### Actual Output

| Campaign | Send Rows | Distinct Customers |
| -------: | --------: | -----------------: |
|     9001 |        10 |                 10 |
|     9002 |         2 |                  2 |
|     9003 |         1 |                  1 |
|     9004 |         4 |                  4 |
|     9101 |         7 |                  6 |
|     9201 |         5 |                  5 |
|     9202 |         1 |                  1 |

The key observation is:

```text
Campaign 9101
Send rows          = 7
Distinct customers = 6
```

This is caused by customer `C20` appearing twice in the standalone campaign.

---

# Step 3 — Identify Campaign Eligibility

Eligible campaigns must satisfy:

```sql
creation_status IN (
    'approved',
    'aborted',
    'resumed',
    'stopped'
)
AND processing_status = 'processed'
```

Campaign `9004` fails the creation-status condition:

```text
9004
creation_status = approval_awaiting
```

Therefore:

```text
Naive raw rows       = 30
Pending campaign     =  4
Eligible raw rows    = 26
```

---

# Step 4 — Identify Retry Relationships

The `parent_id` relationships reveal the retry structure.

### Cart Recovery

```text
9001 → 9002 → 9003
```

### Wave 2

```text
9201 → 9202
```

### Flash Sale

```text
9101
```

Standalone.

### Pending Branch

```text
9004
```

Linked to `9001`, but excluded because it is still pending approval.

---

# Step 5 — Apply Campaign-Specific Reporting Treatment

| Campaign Group            | Raw Rows | Treatment                             | Final Count |
| ------------------------- | -------: | ------------------------------------- | ----------: |
| Cart Recovery `9001–9003` |       13 | Distinct customers across retry chain |      **10** |
| Flash Sale `9101`         |        7 | Count every standalone event          |       **7** |
| Pending `9004`            |        4 | Exclude                               |       **0** |
| Wave 2 `9201–9202`        |        6 | Distinct customers across retry chain |       **5** |
| **Total**                 |   **30** |                                       |      **22** |

---

# 🧮 Reconciliation Bridge

The reconciliation can be summarized as:

```text
                         Count
────────────────────────────────────
Naive raw communication rows    30
Less: pending campaign 9004     -4
────────────────────────────────────
Eligible raw rows               26

Cart Recovery retry chain       10
Flash Sale standalone            7
Wave 2 retry chain               5
────────────────────────────────────
Final target_base               22
```

The final campaign-level calculation is:

```text
Cart Recovery = 10
Flash Sale    =  7
Wave 2        =  5
──────────────────
Total         = 22
```

---

# 💻 Final SQL

The final query first identifies qualifying campaigns and then applies different counting logic to retry chains and the standalone campaign.

```sql
WITH qualifying_campaigns AS (
    SELECT id
    FROM campaign
    WHERE merchant_id = 501
      AND creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND processing_status = 'processed'
),

counts AS (

    SELECT
        'Cart Recovery chain' AS group_name,
        COUNT(DISTINCT cl.customer_id) AS target_base
    FROM communication_log cl
    JOIN qualifying_campaigns c
        ON c.id = cl.communication_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'
      AND cl.communication_id IN (9001, 9002, 9003)

    UNION ALL

    SELECT
        'Flash Sale standalone',
        COUNT(*)
    FROM communication_log cl
    JOIN qualifying_campaigns c
        ON c.id = cl.communication_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'
      AND cl.communication_id = 9101

    UNION ALL

    SELECT
        'Wave 2 chain',
        COUNT(DISTINCT cl.customer_id)
    FROM communication_log cl
    JOIN qualifying_campaigns c
        ON c.id = cl.communication_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'
      AND cl.communication_id IN (9201, 9202)
)

SELECT
    group_name,
    target_base
FROM counts

UNION ALL

SELECT
    'TOTAL target_base',
    SUM(target_base)
FROM counts;
```

---

# ✅ Final SQL Output

```text
Cart Recovery chain   | 10
Flash Sale standalone |  7
Wave 2 chain          |  5
TOTAL target_base     | 22
```

---

# 📈 Final Reconciliation

| Measure                        |                       Value |
| ------------------------------ | --------------------------: |
| Naive raw send count           |                          30 |
| Finance-reported `target_base` |                          22 |
| Calculated `target_base`       |                          22 |
| Difference                     |                       **0** |
| Status                         | **Successfully Reconciled** |

---

# 💡 Important Data Findings

## Finding 1 — C20 is not a duplicate to remove

Customer `C20` appears twice under campaign `9101`:

```text
9101 | C20 | 2026-10-10
9101 | C20 | 2026-10-20
```

Because `9101` is standalone, both are legitimate send events.

**Result:**

```text
9101 = 7
```

not `6`.

---

## Finding 2 — C3 is a retry duplicate

Customer `C3` appears across:

```text
9001 | C3
9002 | C3
9003 | C3
```

The `parent_id` relationships show that these campaigns belong to the same retry chain.

Therefore:

```text
C3 = 1 target-base customer
```

not `3`.

---

## Finding 3 — A communication row does not automatically mean eligibility

Campaign `9004` already has four communication-log records:

```text
9004 | C11
9004 | C12
9004 | C13
9004 | C14
```

However:

```text
creation_status = approval_awaiting
```

Therefore, these rows do not contribute to Finance's metric.

This demonstrates why campaign-level eligibility must be checked before calculating the final metric.

---

# 🎤 Interview Explanation

A concise way to explain the project:

> “I started with the most straightforward count of campaign communication rows for merchant 501 in October 2026, which gave me 30, while Finance reported 22. I then investigated the campaign table and communication log to understand the difference. I found that campaign 9004 was still approval_awaiting, so its four rows were not eligible. I also found that 9001–9003 and 9201–9202 were retry chains identified through parent_id, so customers within each chain should be counted once. However, campaign 9101 was standalone, so its seven send events, including two legitimate sends to C20, all count. That gives 10 + 7 + 5 = 22, exactly matching Finance.”

---
# 📝 Notes & Assumptions

* Analysis is scoped to **merchant `501`**.
* Reporting period is **October 2026**.
* SQL uses the exclusive upper bound:

  ```sql
  sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01'
  ```
* Only `communication_type = '2'` campaign communications are included.
* Campaign eligibility is determined using `creation_status` and `processing_status`.
* Retry relationships are identified through `campaign.parent_id`.
* Customers are deduplicated **within retry chains**, not globally.
* Standalone campaign sends remain separate events.
* Delivery status is available for investigation, but it is not used as the primary reconciliation rule.

---

# 🔗 Reproducibility

The complete investigation is contained in:

```text
analysis.sql
```

The database used by the queries is:

```text
Data/comm_log.db
```

The supporting CSV files are:

```text
Data/campaign.csv
Data/communication_log.csv
```

The supplied dataset can be regenerated using:

```bash
python Data/generate_dataset.py
```

---

# 🏁 Final Conclusion

The raw October communication-log count is:

```text
30
```

Finance's reported value is:

```text
22
```

The difference is explained by:

```text
4 rows  → pending campaign 9004
3 rows  → retry duplicates in Cart Recovery
1 row   → retry duplicate in Wave 2
```

while the repeated `C20` send in standalone campaign `9101` remains valid.

Therefore:

```text
Cart Recovery = 10
Flash Sale    =  7
Wave 2        =  5
──────────────────
target_base   = 22
```

## 🎯 Final Reconciled Result

```text
Finance target_base    = 22
Calculated target_base = 22
Difference             = 0
Status                 = Successfully Reconciled
```

> **The Finance-reported `target_base` of 22 is fully reconciled from the raw communication data using reproducible SQL and campaign-level business rules.**
