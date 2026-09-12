SQL Queries and Outputs

1. Check the tables Query / Command

.tables

Output

campaign
communication_log

2. Check `campaign` table structure Query / Command

.schema campaign

Output

CREATE TABLE campaign (
    id integer primary key,
    merchant_id integer not null,
    parent_id integer,
    name text not null,
    creation_status text not null,
    processing_status text not null
);

3. Check communication_log table structure Query / Command

.schema communication_log

Output

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
 4. See all campaigns

Query

sql
SELECT *
FROM campaign;

Output

9001 | 501 | NULL | Diwali Cart Recovery - Wave 1            | approved          | processed
9002 | 501 | 9001 | Diwali Cart Recovery - Retry A           | approved          | processed
9003 | 501 | 9002 | Diwali Cart Recovery - Retry B           | approved          | processed
9004 | 501 | 9001 | Diwali Cart Recovery - Retry C (pending) | approval_awaiting | processed
9101 | 501 | NULL | Diwali Flash Sale - Standalone           | approved          | processed
9201 | 501 | NULL | Diwali Wave 2                            | approved          | processed
9202 | 501 | 9201 | Diwali Wave 2 - Retry                    | approved          | processed


5. See all communication logs

Query

sql
SELECT *
FROM communication_log;


Output

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


6. Count total raw sends — Naive Query

Query

sql
SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';

Output

30

7. Compare send rows vs distinct customers

Query

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


Output


9001 | 10 | 10
9002 |  2 |  2
9003 |  1 |  1
9004 |  4 |  4
9101 |  7 |  6
9201 |  5 |  5
9202 |  1 |  1


8. Count raw rows by campaign group

Query


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


Output


Cart Recovery chain   | 13
Flash Sale standalone |  7
Pending - excluded    |  4
Wave 2 chain          |  6


9. Final Query

Query

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

Output


Cart Recovery chain   | 10
Flash Sale standalone |  7
Wave 2 chain          |  5
TOTAL target_base     | 22

Final Result

target_base = 22

Finance reported:

target_base = 22

Therefore, the result is successfully reconciled.
