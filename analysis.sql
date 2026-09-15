```sql
-- ============================================================
-- Xeno Data Analyst Internship Drive 2026
-- Comm-Log Send Reconciliation
-- ============================================================
--
-- Merchant: 501
-- Reporting Period: October 2026
-- Finance target_base: 22
--
-- Objective:
-- Reproduce Finance's target_base from the raw communication
-- data and explain the reconciliation from the naive count to 22.
--
-- Key investigation areas:
-- 1. Count raw communication rows.
-- 2. Identify campaign eligibility.
-- 3. Identify retry relationships using parent_id.
-- 4. Distinguish retry duplicates from legitimate standalone sends.
-- 5. Produce a reproducible reconciliation to Finance's target_base.
-- ============================================================


-- ============================================================
-- 1. CHECK AVAILABLE TABLES
-- ============================================================

.tables

-- Expected tables:
-- campaign
-- communication_log


-- ============================================================
-- 2. CHECK CAMPAIGN TABLE STRUCTURE
-- ============================================================

.schema campaign

-- Expected structure:
-- id                 : Campaign ID
-- merchant_id        : Merchant ID
-- parent_id          : Parent campaign ID; used to identify retries
-- name               : Campaign name
-- creation_status    : Campaign creation status
-- processing_status  : Campaign processing status


-- ============================================================
-- 3. CHECK COMMUNICATION_LOG TABLE STRUCTURE
-- ============================================================

.schema communication_log

-- Expected structure:
-- id                  : Communication log ID
-- merchant_id         : Merchant ID
-- communication_id    : Campaign ID
-- customer_id         : Customer receiving the communication
-- communication_type  : Communication type
-- delivery_status     : Delivery status
-- sent_time           : Actual send time
-- scheduled_time      : Scheduled send time
-- credit_used         : Credits used
-- channel             : Communication channel


-- ============================================================
-- 4. INSPECT ALL CAMPAIGNS
-- ============================================================

SELECT *
FROM campaign;

-- Relevant campaigns for merchant 501:
--
-- 9001 -> Diwali Cart Recovery - Wave 1
-- 9002 -> Diwali Cart Recovery - Retry A
-- 9003 -> Diwali Cart Recovery - Retry B
-- 9004 -> Diwali Cart Recovery - Retry C (pending)
-- 9101 -> Diwali Flash Sale - Standalone
-- 9201 -> Diwali Wave 2
-- 9202 -> Diwali Wave 2 - Retry
--
-- parent_id shows the retry relationship:
--
-- 9001 -> 9002 -> 9003
-- 9001 -> 9004
-- 9201 -> 9202


-- ============================================================
-- 5. INSPECT ALL COMMUNICATION LOGS
-- ============================================================

SELECT *
FROM communication_log;


-- ============================================================
-- 6. NAIVE RAW COMMUNICATION COUNT
-- ============================================================
--
-- Finance target_base = 22.
--
-- First, calculate the straightforward count of all campaign
-- communication rows for merchant 501 during October 2026.
--
-- sent_time is used to define the reporting period.
-- communication_type = '2' represents campaign communication.
-- ============================================================

SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';

-- Result:
-- naive_send_count = 30
--
-- Finance target_base = 22
--
-- Initial difference:
-- 30 - 22 = 8
--
-- Therefore, further investigation is required.


-- ============================================================
-- 7. COMPARE RAW SEND ROWS VS DISTINCT CUSTOMERS
-- ============================================================
--
-- This comparison helps identify campaigns where multiple
-- communication rows may represent retry attempts for the
-- same customer.
-- ============================================================

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

-- Result:
--
-- communication_id | send_rows | distinct_customers
-- -------------------------------------------------
-- 9001             |    10     |       10
-- 9002             |     2     |        2
-- 9003             |     1     |        1
-- 9004             |     4     |        4
-- 9101             |     7     |        6
-- 9201             |     5     |        5
-- 9202             |     1     |        1
--
-- Important observation:
--
-- Campaign 9101 has 7 send rows but only 6 distinct customers.
-- Customer C20 received two sends on different dates.
--
-- Because 9101 is a standalone campaign, these are legitimate
-- separate send events and should NOT be deduplicated globally.
--
-- In contrast, repeated customers across retry chains may
-- represent the same underlying communication journey.


-- ============================================================
-- 8. IDENTIFY ELIGIBLE CAMPAIGNS
-- ============================================================
--
-- Campaign eligibility rule:
--
-- creation_status must be one of:
--   approved
--   aborted
--   resumed
--   stopped
--
-- AND
--
-- processing_status must be:
--   processed
-- ============================================================

SELECT
    id,
    name,
    parent_id,
    creation_status,
    processing_status
FROM campaign
WHERE merchant_id = 501
ORDER BY id;


-- ============================================================
-- 9. IDENTIFY CAMPAIGNS EXCLUDED BY ELIGIBILITY RULES
-- ============================================================

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

-- Result:
--
-- Campaign 9004 is excluded because:
--
-- creation_status = 'approval_awaiting'
--
-- Although campaign 9004 has 4 communication_log rows,
-- those rows are not eligible for Finance's target_base.
--
-- Therefore:
--
-- Naive count = 30
-- Less pending campaign 9004 = 4
-- Eligible rows = 26


-- ============================================================
-- 10. INSPECT RETRY RELATIONSHIPS
-- ============================================================

SELECT
    id,
    name,
    parent_id
FROM campaign
WHERE merchant_id = 501
ORDER BY id;

-- Retry relationships identified:
--
-- Cart Recovery:
-- 9001 -> 9002 -> 9003
--
-- Campaign 9004 is also linked to 9001 but is excluded
-- because it is approval_awaiting.
--
-- Wave 2:
-- 9201 -> 9202
--
-- Flash Sale:
-- 9101 is standalone.
--
-- Therefore, the reporting treatment is:
--
-- Cart Recovery chain -> count each customer once
-- Flash Sale standalone -> count every send event
-- Wave 2 chain       -> count each customer once


-- ============================================================
-- 11. COUNT RAW ROWS BY CAMPAIGN GROUP
-- ============================================================

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


-- Expected result:
--
-- Cart Recovery chain   | 13
-- Flash Sale standalone |  7
-- Pending - excluded    |  4
-- Wave 2 chain          |  6
--
-- Total raw rows = 30
--
-- After excluding pending campaign 9004:
--
-- 13 + 7 + 6 = 26 eligible raw rows
--
-- These 26 rows still need reconciliation because retry
-- campaigns can contain duplicate customer journeys.


-- ============================================================
-- 12. FINAL RECONCILIATION
-- ============================================================
--
-- Business treatment:
--
-- 1. Cart Recovery retry chain (9001, 9002, 9003):
--    Count each customer once across the retry chain.
--
-- 2. Flash Sale standalone (9101):
--    Count every send event.
--    The two C20 sends are legitimate separate sends.
--
-- 3. Wave 2 retry chain (9201, 9202):
--    Count each customer once across the retry chain.
-- ============================================================

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

    -- --------------------------------------------------------
    -- Cart Recovery retry chain
    -- --------------------------------------------------------
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


    -- --------------------------------------------------------
    -- Flash Sale standalone campaign
    -- --------------------------------------------------------
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


    -- --------------------------------------------------------
    -- Wave 2 retry chain
    -- --------------------------------------------------------
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


-- ------------------------------------------------------------
-- Return campaign-group counts and final total
-- ------------------------------------------------------------

SELECT
    group_name,
    target_base
FROM counts

UNION ALL

SELECT
    'TOTAL target_base',
    SUM(target_base)
FROM counts;


-- Expected result:
--
-- Cart Recovery chain   | 10
-- Flash Sale standalone |  7
-- Wave 2 chain          |  5
-- TOTAL target_base     | 22


-- ============================================================
-- 13. RECONCILIATION SUMMARY
-- ============================================================
--
-- Naive raw communication count                 30
--
-- Less: pending campaign 9004                    4
-- Eligible raw rows                              26
--
-- Cart Recovery retry chain                     10
-- Flash Sale standalone                          7
-- Wave 2 retry chain                             5
--
-- Final reconciled target_base                  22
--
-- Finance target_base                           22
--
-- Difference                                      0
-- ============================================================


-- ============================================================
-- 14. FINAL CONCLUSION
-- ============================================================
--
-- The straightforward October communication-log count is 30,
-- while Finance reported a target_base of 22.
--
-- The difference is explained by two business rules:
--
-- 1. Campaign eligibility:
--    Campaign 9004 is still approval_awaiting, so its 4
--    communication rows are excluded from the target_base.
--
-- 2. Retry reconciliation:
--    Campaigns 9001-9002-9003 form a retry chain and customers
--    in this chain are counted once, resulting in 10.
--
--    Campaigns 9201-9202 form another retry chain and customers
--    in this chain are counted once, resulting in 5.
--
--    Campaign 9101 is standalone, so all 7 send events count.
--    This includes two legitimate sends to customer C20.
--
-- Final calculation:
--
--     10 + 7 + 5 = 22
--
-- Final reconciled target_base = 22
--
-- This exactly matches Finance's reported target_base.
-- ============================================================
```
