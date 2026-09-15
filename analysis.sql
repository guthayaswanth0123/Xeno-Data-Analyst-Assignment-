# Xeno Data Analyst Internship Drive 2026

# Comm-Log Send Reconciliation

**Merchant:** 501
**Reporting Period:** October 2026
**Finance target_base:** 22

---

## Objective

Reproduce Finance's `target_base` from the raw communication data and explain the reconciliation from the naive count to 22.

The investigation focuses on:

1. Understanding the available tables.
2. Inspecting the raw campaign and communication data.
3. Calculating the naive communication count.
4. Identifying campaign eligibility.
5. Identifying retry relationships using `parent_id`.
6. Distinguishing retry duplicates from legitimate standalone sends.
7. Producing a reproducible SQL reconciliation.
8. Confirming the final result against Finance's reported `target_base` of 22.

---

# SQL Queries and Outputs

## 1. Check the Tables

### Query / Command

```sql
.tables
```

### Output

```text
campaign
communication_log
```

### Observation

The database contains two relevant tables:

* `campaign` — contains campaign information and campaign status.
* `communication_log` — contains individual communication/send records.

---

## 2. Check `campaign` Table Structure

### Query / Command

```sql
.schema campaign
```

### Output

```sql
CREATE TABLE campaign (
    id integer primary key,
    merchant_id integer not null,
    parent_id integer,
    name text not null,
    creation_status text not null,
    processing_status text not null
);
```

### Observation

Important columns:

* `id` → campaign ID
* `merchant_id` → identifies the merchant
* `parent_id` → identifies the parent campaign and helps identify retries
* `name` → campaign name
* `creation_status` → campaign creation/approval state
* `processing_status` → processing state

---

## 3. Check `communication_log` Table Structure

### Query / Command

```sql
.schema communication_log
```

### Output

```sql
CREATE TABLE communication_log (
    id integer primary key,
    merchant_id integer not null,
    communication_id integer not null,
    customer_id text not null,
    communication_type text not null,
    delivery_status integer not null,
    sent_time text not null,
    scheduled_time text not null,
    credit_used integer not null,
    channel text not null
);
```

### Observation

Important columns:

* `communication_id` → links the communication to a campaign
* `customer_id` → customer who received the communication
* `communication_type` → identifies the communication type
* `delivery_status` → delivery result
* `sent_time` → actual send time
* `scheduled_time` → scheduled send time

For this reconciliation:

* `communication_type = '2'` represents campaign communication.
* `sent_time` defines the October 2026 reporting period.

---

# 4. See All Campaigns

### Query

```sql
SELECT *
FROM campaign;
```

### Output

```text
9001 | 501 | NULL | Diwali Cart Recovery - Wave 1            | approved          | processed
9002 | 501 | 9001 | Diwali Cart Recovery - Retry A           | approved          | processed
9003 | 501 | 9002 | Diwali Cart Recovery - Retry B           | approved          | processed
9004 | 501 | 9001 | Diwali Cart Recovery - Retry C (pending) | approval_awaiting | processed
9101 | 501 | NULL | Diwali Flash Sale - Standalone           | approved          | processed
9201 | 501 | NULL | Diwali Wave 2                            | approved          | processed
9202 | 501 | 9201 | Diwali Wave 2 - Retry                    | approved          | processed
```

### Observation

The campaign relationships are:

```text
Cart Recovery:

9001
  ↓
9002
  ↓
9003

9004 is also linked to 9001 but is pending.
```

```text
Wave 2:

9201
  ↓
9202
```

```text
Flash Sale:

9101

Standalone campaign
```

The `parent_id` column is therefore important for identifying retry campaigns.

---

# 5. See All Communication Logs

### Query

```sql
SELECT *
FROM communication_log;
```

### Output

```text
1  | 501 | 9001 | C1  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
2  | 501 | 9001 | C2  | 2 | 1100 | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
3  | 501 | 9002 | C2  | 2 | 900  | 2026-10-04 10:00:00 | 2026-10-04 10:00:00 | 1 | sms
4  | 501 | 9001 | C3  | 2 | 1100 | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
5  | 501 | 9002 | C3  | 2 | 1100 | 2026-10-04 10:00:00 | 2026-10-04 10:00:00 | 1 | sms
6  | 501 | 9003 | C3  | 2 | 900  | 2026-10-05 10:00:00 | 2026-10-05 10:00:00 | 1 | sms
7  | 501 | 9001 | C4  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
8  | 501 | 9001 | C5  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
9  | 501 | 9001 | C6  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
10 | 501 | 9001 | C7  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
11 | 501 | 9001 | C8  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
12 | 501 | 9001 | C9  | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
13 | 501 | 9001 | C10 | 2 | 900  | 2026-10-03 10:00:00 | 2026-10-03 10:00:00 | 1 | sms
14 | 501 | 9004 | C11 | 2 | 900  | 2026-10-06 10:00:00 | 2026-10-06 10:00:00 | 1 | sms
15 | 501 | 9004 | C12 | 2 | 900  | 2026-10-06 10:00:00 | 2026-10-06 10:00:00 | 1 | sms
16 | 501 | 9004 | C13 | 2 | 900  | 2026-10-06 10:00:00 | 2026-10-06 10:00:00 | 1 | sms
17 | 501 | 9004 | C14 | 2 | 900  | 2026-10-06 10:00:00 | 2026-10-06 10:00:00 | 1 | sms
18 | 501 | 9101 | C20 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
19 | 501 | 9101 | C20 | 2 | 900  | 2026-10-20 10:00:00 | 2026-10-20 10:00:00 | 1 | sms
20 | 501 | 9101 | C21 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
21 | 501 | 9101 | C22 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
22 | 501 | 9101 | C23 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
23 | 501 | 9101 | C24 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
24 | 501 | 9101 | C25 | 2 | 900  | 2026-10-10 10:00:00 | 2026-10-10 10:00:00 | 1 | sms
25 | 501 | 9201 | D1  | 2 | 1100 | 2026-10-07 10:00:00 | 2026-10-07 10:00:00 | 1 | sms
26 | 501 | 9202 | D1  | 2 | 900  | 2026-10-08 10:00:00 | 2026-10-08 10:00:00 | 1 | sms
27 | 501 | 9201 | D2  | 2 | 900  | 2026-10-07 10:00:00 | 2026-10-07 10:00:00 | 1 | sms
28 | 501 | 9201 | D3  | 2 | 900  | 2026-10-07 10:00:00 | 2026-10-07 10:00:00 | 1 | sms
29 | 501 | 9201 | D4  | 2 | 900  | 2026-10-07 10:00:00 | 2026-10-07 10:00:00 | 1 | sms
30 | 501 | 9201 | D5  | 2 | 900  | 2026-10-07 10:00:00 | 2026-10-07 10:00:00 | 1 | sms
```

### Observation

There are **30 communication rows** for merchant 501 during October.

Some customers appear more than once:

* C2 appears in campaigns 9001 and 9002.
* C3 appears in campaigns 9001, 9002 and 9003.
* C20 appears twice in standalone campaign 9101.
* D1 appears in campaigns 9201 and 9202.

These repeated records need to be investigated rather than automatically removed.

---

# 6. Count Total Raw Sends — Naive Query

### Query

```sql
SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';
```

### Actual Output

```text
30
```

### Observation

The straightforward raw-row count is:

```text
Naive count = 30
```

Finance reported:

```text
Finance target_base = 22
```

Therefore:

```text
30 - 22 = 8
```

There is an **8-row difference** that needs to be explained.

---

# 7. Compare Send Rows vs Distinct Customers

### Query

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

```text
9001 | 10 | 10
9002 |  2 |  2
9003 |  1 |  1
9004 |  4 |  4
9101 |  7 |  6
9201 |  5 |  5
9202 |  1 |  1
```

### Observation

The important difference is campaign `9101`:

```text
Send rows             = 7
Distinct customers    = 6
```

This happens because customer `C20` received two separate sends:

```text
2026-10-10
2026-10-20
```

Since campaign `9101` is a **standalone campaign**, these are legitimate separate send events.

Therefore, we should **not** globally use:

```sql
COUNT(DISTINCT customer_id)
```

because that would incorrectly remove one legitimate Flash Sale send.

For retry chains, however, repeated customers can represent the same underlying communication journey.

---

# 8. Identify Eligible Campaigns

### Query

```sql
SELECT
    id,
    name,
    parent_id,
    creation_status,
    processing_status
FROM campaign
WHERE merchant_id = 501
ORDER BY id;
```

### Output

```text
9001 | Diwali Cart Recovery - Wave 1            | NULL | approved          | processed
9002 | Diwali Cart Recovery - Retry A           | 9001 | approved          | processed
9003 | Diwali Cart Recovery - Retry B           | 9002 | approved          | processed
9004 | Diwali Cart Recovery - Retry C (pending) | 9001 | approval_awaiting | processed
9101 | Diwali Flash Sale - Standalone           | NULL | approved          | processed
9201 | Diwali Wave 2                            | NULL | approved          | processed
9202 | Diwali Wave 2 - Retry                    | 9201 | approved          | processed
```

### Eligibility Rule

A campaign qualifies when:

```text
creation_status IN
('approved', 'aborted', 'resumed', 'stopped')

AND

processing_status = 'processed'
```

---

# 9. Identify Campaigns Excluded by Eligibility Rules

### Query

```sql
SELECT
    id,
    name,
    creation_status,
    processing_status
FROM campaign
WHERE merchant_id = 501
  AND NOT (
      creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND processing_status = 'processed'
  );
```

### Actual Output

```text
9004 | Diwali Cart Recovery - Retry C (pending) | approval_awaiting | processed
```

### Observation

Campaign `9004` is excluded because:

```text
creation_status = approval_awaiting
```

Although it has 4 communication-log rows, those rows are **not eligible** for Finance's `target_base`.

Therefore:

```text
Naive raw rows       = 30
Pending campaign     =  4
Eligible raw rows    = 26
```

---

# 10. Inspect Retry Relationships

### Query

```sql
SELECT
    id,
    name,
    parent_id
FROM campaign
WHERE merchant_id = 501
ORDER BY id;
```

### Actual Output

```text
9001 | Diwali Cart Recovery - Wave 1            | NULL
9002 | Diwali Cart Recovery - Retry A           | 9001
9003 | Diwali Cart Recovery - Retry B           | 9002
9004 | Diwali Cart Recovery - Retry C (pending) | 9001
9101 | Diwali Flash Sale - Standalone           | NULL
9201 | Diwali Wave 2                            | NULL
9202 | Diwali Wave 2 - Retry                    | 9201
```

### Retry Chains Identified

**Cart Recovery:**

```text
9001 → 9002 → 9003
```

**Wave 2:**

```text
9201 → 9202
```

**Flash Sale:**

```text
9101
```

`9101` is standalone.

### Reporting Treatment

| Campaign group     | Treatment                |
| ------------------ | ------------------------ |
| 9001 → 9002 → 9003 | Count each customer once |
| 9101               | Count every send event   |
| 9201 → 9202        | Count each customer once |
| 9004               | Exclude                  |

---

# 11. Count Raw Rows by Campaign Group

### Query

```sql
SELECT
    CASE
        WHEN c.id IN (9001, 9002, 9003)
            THEN 'Cart Recovery chain'

        WHEN c.id = 9101
            THEN 'Flash Sale standalone'

        WHEN c.id IN (9201, 9202)
            THEN 'Wave 2 chain'

        WHEN c.id = 9004
            THEN 'Pending - excluded'
    END AS group_name,

    COUNT(cl.id) AS raw_send_rows

FROM campaign c

LEFT JOIN communication_log cl
    ON cl.communication_id = c.id

WHERE c.merchant_id = 501

GROUP BY group_name
ORDER BY group_name;
```

### Actual Output

```text
Cart Recovery chain   | 13
Flash Sale standalone |  7
Pending - excluded    |  4
Wave 2 chain          |  6
```

### Observation

Total:

```text
13 + 7 + 4 + 6 = 30
```

After excluding campaign `9004`:

```text
13 + 7 + 6 = 26
```

These 26 eligible rows still need reconciliation because retry campaigns can contain multiple communication rows for the same customer journey.

---

# 12. Final Reconciliation

## Business Rules

### Cart Recovery — 9001, 9002, 9003

These campaigns form a retry chain:

```text
9001 → 9002 → 9003
```

Customers should be counted once across the chain.

Result:

```text
10
```

### Flash Sale — 9101

This is a standalone campaign.

All send events count, including both sends to C20.

Result:

```text
7
```

### Wave 2 — 9201, 9202

These campaigns form a retry chain:

```text
9201 → 9202
```

Customers should be counted once across the chain.

Result:

```text
5
```

---

## Final Query

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

## Actual Output

```text
Cart Recovery chain   | 10
Flash Sale standalone |  7
Wave 2 chain          |  5
TOTAL target_base     | 22
```

---

# 13. Reconciliation Bridge

| Step                         |  Count |
| ---------------------------- | -----: |
| Naive raw communication rows |     30 |
| Less: pending campaign 9004  |     -4 |
| Eligible raw rows            |     26 |
| Cart Recovery retry chain    |     10 |
| Flash Sale standalone        |      7 |
| Wave 2 retry chain           |      5 |
| **Final target_base**        | **22** |

The final campaign-level calculation is:

```text
Cart Recovery = 10
Flash Sale    = 7
Wave 2        = 5
------------------
Total         = 22
```

---

# 14. Surprising / Important Data Findings

### 1. Customer C20 appears twice in Flash Sale

```text
9101 | C20 | 2026-10-10
9101 | C20 | 2026-10-20
```

This is **not a retry duplicate** because `9101` is a standalone campaign.

Therefore, both sends count.

---

### 2. Customer C3 appears across a retry chain

```text
9001 | C3
9002 | C3
9003 | C3
```

These represent the same underlying communication journey.

Therefore, C3 is counted **once**, not three times.

---

### 3. Campaign 9004 contains communication rows despite being pending

Campaign `9004` has four communication-log records, but:

```text
creation_status = approval_awaiting
```

Therefore, simply having a communication row does not mean that the campaign should contribute to Finance's metric.

---

# 15. Final Result

```text
target_base = 22
```

Finance reported:

```text
target_base = 22
```

Therefore:

```text
Calculated target_base = Finance target_base
22 = 22
```

**The result is successfully reconciled.**

---

# 16. Final Conclusion

The naive October communication-log count is **30**, while Finance reported a `target_base` of **22**.

The difference is explained by the campaign eligibility and retry rules.

Campaign `9004` is excluded because it is still `approval_awaiting`, removing **4 rows** from consideration.

Campaigns `9001`, `9002`, and `9003` form a retry chain. Customers in this chain are counted once, resulting in **10**.

Campaign `9101` is a standalone campaign. All **7 send events** are legitimate, including the two separate sends to customer `C20`.

Campaigns `9201` and `9202` form another retry chain. Customers are counted once, resulting in **5**.

Therefore:

```text
10 + 7 + 5 = 22
```

**Final reconciled `target_base` = 22**

This exactly matches Finance's reported `target_base`.

---

# Final Reconciliation

```text
Finance target_base       = 22
Calculated target_base    = 22
Difference                = 0
Status                    = Successfully Reconciled
```
