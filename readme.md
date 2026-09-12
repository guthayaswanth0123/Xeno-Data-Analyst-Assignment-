

Comm-Log Send Reconciliation

Xeno Data Analyst Internship - Take-Home Assignment

Merchant: 501
Reporting Period: October 2026
Campaign Scope: Diwali campaigns
Metric: target_base
Finance Reported Value: 22
Reconciled Value: 22

1. Executive Summary

The objective of this analysis is to reproduce Finance's reported target_base value for merchant 501 during October 2026 across the Diwali campaigns.

Finance reports:
target_base = 22

The raw communication_log table contains 30 campaign send rows for the requested merchant, month, and communication type. A simple COUNT(*) therefore produces:

Naive count = 30

However, this is not the correct reporting metric.

The investigation identified two important characteristics in the raw data:

1. One campaign branch is still awaiting approval.

Campaign 9004 has creation_status = 'approval_awaiting'.
Although four communication-log rows already exist for this campaign, the data dictionary states that campaigns still awaiting approval do not count toward official reporting.
Therefore, these four rows must be excluded.

2. Some campaigns are retries of earlier campaigns.

Campaigns are connected through campaign.parent_id.
A retry represents another attempt at the same underlying communication.
Therefore, customers appearing across a retry chain should be counted once for that underlying communication rather than once for every retry attempt.

There are also standalone campaigns where repeated sends to the same customer are legitimate independent events. In particular, customer C20 appears twice under standalone campaign 9101. These two events should both count.

After applying the reporting eligibility rule and correctly handling retry chains, the final reconciliation is:

Cart Recovery retry chain: 10
Flash Sale standalone: 7
Wave 2 retry chain: 5
Final target_base: 22

Therefore:

Finance target_base = 22
Calculated target_base = 22
Difference = 0

The Finance number is successfully reconciled.

2. Assignment Objective

The assignment asks us to reproduce Finance's target_base metric from the raw data and explain the difference between the most straightforward query and the final correct result.

The key question is:

For merchant 501, in October 2026, across the Diwali campaigns, how many qualifying sends should contribute to target_base?

The analysis must not simply produce the number 22.

The important part of the exercise is demonstrating:

- what the initial query was
- what result it produced
- why that result was incorrect
- what was investigated next
- which records needed to be excluded
- which records represented retries
- which repeated customers were legitimate
- and how each adjustment changed the result

3. Data Sources

The assignment provides a SQLite database:

comm_log.db

It also provides equivalent CSV files:

campaign.csv
communication_log.csv

SQLite was used for this analysis because it allows the investigation to be performed directly against the supplied database.

The database contains two tables:

campaign
communication_log

The data dictionary describes the database as containing one campaign table and one communication-log table.

4. Database Schema

4.1 campaign

The campaign table contains one row for each campaign.

The important columns are:

Column: id
Meaning: Unique campaign identifier

Column: merchant_id
Meaning: Merchant owning the campaign

Column: parent_id
Meaning: Parent campaign if this campaign is a retry

Column: name
Meaning: Human-readable campaign name

Column: creation_status
Meaning: Campaign creation/approval lifecycle status

Column: processing_status
Meaning: Status of the send-processing workflow

The data dictionary explains that parent_id is the key used to identify retry relationships. A NULL parent_id means the campaign was not itself created as a retry.

4.2 communication_log

The communication_log table contains one row per individual send attempt.

Important columns are:

Column: id
Meaning: Unique send-attempt row

Column: merchant_id
Meaning: Merchant associated with the send

Column: communication_id
Meaning: Campaign ID associated with the send

Column: customer_id
Meaning: Customer targeted by the send

Column: communication_type
Meaning: Type of communication

Column: delivery_status
Meaning: Delivery result

Column: sent_time
Meaning: Time the send occurred

Column: scheduled_time
Meaning: Scheduled time

Column: credit_used
Meaning: Billing credits used

Column: channel
Meaning: Communication channel

The data dictionary specifies that communication_type = '2' represents a campaign communication. It also defines 900 as delivered and 1100 as a soft failure that may lead to a retry or later re-targeting.

5. Important Reporting Rules

Before calculating the final number, the business rules in the supplied data need to be understood.

5.1 Campaign eligibility

A campaign is eligible for official reporting only when:

creation_status IN (
    'approved',
    'aborted',
    'resumed',
    'stopped'
)

and:

processing_status = 'processed'

The data dictionary explicitly states that a campaign with creation_status = 'approval_awaiting' has not cleared approval and therefore does not count toward reported sends, even if rows already exist in communication_log.

This distinction is important because the send pipeline can contain rows for a campaign before its approval bookkeeping has completed.

6. Understanding Retry Chains

A campaign can be a retry of another campaign.

For example:

9001
  |
  └── 9002
        |
        └── 9003

The parent_id values establish this relationship.

Specifically:

9001 = original campaign
9002 = retry of 9001
9003 = retry of 9002

The data dictionary states that a retry chain can contain multiple levels. A customer who was sent campaign A, then B, then C is considered to have been targeted by the same underlying communication rather than three independent communications.

Therefore, simply counting every row in the communication log would overstate the target_base.

7. Understanding Standalone Campaigns

Not every repeated customer is a duplicate that should be removed.

The data dictionary makes an important distinction between:

- retries represented by separate campaign rows, and
- legitimate repeated sends under a standalone campaign.

A customer can appear more than once against the same communication_id.

This can represent an independently re-run campaign or a customer being legitimately re-targeted later. That is different from a retry chain.

For a standalone campaign, every send event counts independently.

This becomes important for campaign 9101, where customer C20 appears twice.

8. Initial Investigation

The first step was to inspect the database structure.

Query:

.tables

The database contains:

campaign
communication_log

9. Inspecting the Campaign Schema

The campaign table has the following structure:

CREATE TABLE campaign (
    id integer primary key,
    merchant_id integer not null,
    parent_id integer,
    name text not null,
    creation_status text not null,
    processing_status text not null
);

The most important fields for this reconciliation are:

id
merchant_id
parent_id
creation_status
processing_status

parent_id allows us to determine whether a campaign is part of a retry chain.

creation_status and processing_status allow us to determine whether a campaign is eligible for reporting.

10. Inspecting the Communication Log Schema

The communication log has the following structure:

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

The most important fields for this analysis are:

merchant_id
communication_id
customer_id
communication_type
delivery_status
sent_time

11. Inspecting All Campaigns

The campaign data for merchant 501 is:

Campaign ID: 9001 | Parent ID: NULL | Campaign: Diwali Cart Recovery - Wave 1 | Creation Status: approved | Processing Status: processed
Campaign ID: 9002 | Parent ID: 9001 | Campaign: Diwali Cart Recovery - Retry A | Creation Status: approved | Processing Status: processed
Campaign ID: 9003 | Parent ID: 9002 | Campaign: Diwali Cart Recovery - Retry B | Creation Status: approved | Processing Status: processed
Campaign ID: 9004 | Parent ID: 9001 | Campaign: Diwali Cart Recovery - Retry C (pending) | Creation Status: approval_awaiting | Processing Status: processed
Campaign ID: 9101 | Parent ID: NULL | Campaign: Diwali Flash Sale - Standalone | Creation Status: approved | Processing Status: processed
Campaign ID: 9201 | Parent ID: NULL | Campaign: Diwali Wave 2 | Creation Status: approved | Processing Status: processed
Campaign ID: 9202 | Parent ID: 9201 | Campaign: Diwali Wave 2 - Retry | Creation Status: approved | Processing Status: processed

This immediately reveals three important groups.

Group 1 - Cart Recovery

9001 -> 9002 -> 9003

This is a retry chain.

Group 2 - Pending branch

9004

This is associated with the Cart Recovery family but is still:

creation_status = approval_awaiting

Therefore it is ineligible.

Group 3 - Flash Sale

9101

This is a standalone campaign.

Group 4 - Wave 2

9201 -> 9202

This is another retry chain.

12. Naive Query

The first and most straightforward approach is to count every campaign communication-log row for the required merchant, month, and communication type.

Query:

SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';

Result:

30

So the initial result is:

Naive target_base = 30

However, Finance reports:

Finance target_base = 22

Therefore the gap is:

30 - 22 = 8

At this point, the investigation needs to determine where those eight excess rows come from.

13. First Investigation - Compare Send Rows With Distinct Customers

The next step is to determine whether the raw send rows contain repeated customers.

Query:

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

Result:

Campaign: 9001 | Send Rows: 10 | Distinct Customers: 10
Campaign: 9002 | Send Rows: 2 | Distinct Customers: 2
Campaign: 9003 | Send Rows: 1 | Distinct Customers: 1
Campaign: 9004 | Send Rows: 4 | Distinct Customers: 4
Campaign: 9101 | Send Rows: 7 | Distinct Customers: 6
Campaign: 9201 | Send Rows: 5 | Distinct Customers: 5
Campaign: 9202 | Send Rows: 1 | Distinct Customers: 1

This result is extremely useful.

It shows:

- Campaign 9101 has 7 send rows but only 6 distinct customers.
- Therefore, at least one customer was sent twice under campaign 9101.
- However, this does not automatically mean one row should be removed.
- We need to understand whether 9101 is a retry campaign or a standalone campaign.

We also see that campaigns 9001, 9002, and 9003 have separate customers within each campaign, but they may represent the same underlying communications because they form a retry chain.

Similarly, 9201 and 9202 form a retry chain.

14. Investigating Campaign Families

To understand the impact of the campaign relationships, the send rows were grouped by campaign family.

The campaign groups are:

Cart Recovery chain:
9001 -> 9002 -> 9003

Flash Sale standalone:
9101

Pending branch:
9004

Wave 2 chain:
9201 -> 9202

The raw send counts by group are:

Group: Cart Recovery chain | Raw Send Rows: 13
Group: Flash Sale standalone | Raw Send Rows: 7
Group: Pending branch | Raw Send Rows: 4
Group: Wave 2 chain | Raw Send Rows: 6
Total: 30

The total agrees with the naive query:

13 + 7 + 4 + 6 = 30

15. Adjustment 1 - Exclude the Pending Campaign

Campaign 9004 is:

Diwali Cart Recovery - Retry C (pending)

Its statuses are:

creation_status = approval_awaiting
processing_status = processed

The important point is that processing_status = processed by itself is not sufficient.

The campaign must also have a finalized creation/approval status.

The eligible creation statuses are:

approved
aborted
resumed
stopped

But 9004 has:

approval_awaiting

Therefore campaign 9004 is not eligible.

There are four communication-log rows associated with it:

C11
C12
C13
C14

Those four rows must be excluded.

Therefore:

30 - 4 = 26

After applying campaign eligibility:

Eligible raw sends = 26

This is the first major reconciliation adjustment.

16. Adjustment 2 - Collapse the Cart Recovery Retry Chain

The next issue is the Cart Recovery family:

9001 -> 9002 -> 9003

These are not three independent communications.

They represent a retry chain.

The raw rows are:

Campaign 9001

Customers:
C1
C2
C3
C4
C5
C6
C7
C8
C9
C10

Campaign 9002

Customers:
C2
C3

Campaign 9003

Customer:
C3

The same customers appear across the retry chain because customers who failed an earlier attempt were retried.

For example:

C3:
9001 -> failed
9002 -> failed
9003 -> delivered

This is three send attempts, but it represents one underlying communication for customer C3.

Therefore C3 must count once, not three times.

Similarly:

C2:
9001 -> failed
9002 -> delivered

This is two attempts but one underlying communication.

After collapsing the entire retry chain to distinct customers, the Cart Recovery family contains:

C1 through C10

Therefore:

Cart Recovery target_base = 10

The raw count for this family was:

13

The corrected count is:

10

Adjustment:

13 - 10 = 3

17. Adjustment 3 - Keep All Seven Flash Sale Events

Campaign 9101 is:

Diwali Flash Sale - Standalone

Its parent_id is NULL, so it is not part of a retry chain.

The send records are:

Customer: C20 | Date: 2026-10-10
Customer: C20 | Date: 2026-10-20
Customer: C21 | Date: 2026-10-10
Customer: C22 | Date: 2026-10-10
Customer: C23 | Date: 2026-10-10
Customer: C24 | Date: 2026-10-10
Customer: C25 | Date: 2026-10-10

There are:

7 send events

but:

6 distinct customers

because C20 appears twice.

It would be tempting to use:

COUNT(DISTINCT customer_id)

for every campaign.

That would produce:

6

for this campaign.

However, that would be incorrect.

The data dictionary explicitly distinguishes legitimate repeated sends within a standalone campaign from retry chains.

For standalone campaigns, each send is an independent event.

Therefore both C20 sends count.

So:

Flash Sale standalone = 7

No adjustment is made to the raw seven rows.

18. Why C20 Is Important

C20 is one of the most important records in the dataset because it demonstrates why the analysis cannot simply use:

COUNT(DISTINCT customer_id)

across all campaigns.

C20 was sent:

2026-10-10

and again:

2026-10-20

under the same standalone campaign 9101.

These are legitimate independent send events.

If we blindly deduplicated C20, we would reduce:

7 -> 6

and incorrectly calculate the final target base as:

21

instead of:

22

This was one of the most important findings during the investigation.

19. Adjustment 4 - Collapse the Wave 2 Retry Chain

The second retry family is:

9201 -> 9202

Campaign 9201 sends to:

D1
D2
D3
D4
D5

Campaign 9202 is a retry of 9201 and sends to:

D1

The raw count is:

9201 = 5
9202 = 1

Total = 6

However, D1 appears in both campaigns:

D1 -> 9201
D1 -> 9202

The second send is a retry of the first communication.

Therefore D1 should count once.

The distinct customers in the entire retry chain are:

D1
D2
D3
D4
D5

Therefore:

Wave 2 target_base = 5

The raw count was:

6

The corrected count is:

5

Adjustment:

6 - 5 = 1

20. Final Reconciliation Bridge

The complete bridge from the naive result to Finance's result is:

Step 0: Naive count of all October campaign send rows | Result: 30 | Reason: Starting point: every matching communication_log row

Step 1: Exclude campaign 9004 | Result: 26 | Reason: 9004 is approval_awaiting and therefore ineligible for official reporting

Step 2: Collapse Cart Recovery retry chain 9001 -> 9002 -> 9003 | Result: 23 | Reason: Multiple attempts for the same underlying communication should count once per customer

Step 3: Keep Flash Sale standalone campaign 9101 as 7 events | Result: 23 | Reason: It is standalone; C20's two sends are legitimate independent events

Step 4: Collapse Wave 2 retry chain 9201 -> 9202 | Result: 22 | Reason: D1 appears in both campaigns but represents one underlying communication

Final: Correct target_base | Result: 22 | Reason: Matches Finance

Another way to show the same calculation is:

Naive raw sends: 30
Less: ineligible campaign 9004: 4
---
Eligible raw sends: 26

Cart Recovery:
    Raw sends: 13
    Distinct customers across retry chain: 10

Flash Sale:
    Raw standalone send events: 7

Wave 2:
    Raw sends: 6
    Distinct customers across retry chain: 5
---
Final target_base: 10 + 7 + 5

FINAL TARGET_BASE: 22

21. Final Group-Level Result

The final calculation can therefore be represented as:

Campaign Family: Cart Recovery | Campaigns: 9001, 9002, 9003 | Reporting Logic: Distinct customers across retry chain | Final Count: 10

Campaign Family: Flash Sale | Campaigns: 9101 | Reporting Logic: Every standalone send event counts | Final Count: 7

Campaign Family: Wave 2 | Campaigns: 9201, 9202 | Reporting Logic: Distinct customers across retry chain | Final Count: 5

Campaign Family: Pending branch | Campaigns: 9004 | Reporting Logic: Excluded because approval is pending | Final Count: 0

Total: 22

Therefore:

10 + 7 + 5 = 22

22. Final SQL

The following SQL implements the final reconciliation.

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

    / Cart Recovery retry chain: 9001 -> 9002 -> 9003
       These campaigns represent one underlying communication
       across retry attempts, so count distinct customers. /
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

    / Flash Sale is a standalone campaign.
       Every send event counts independently, including
       legitimate repeated sends to the same customer. /
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

    / Wave 2 retry chain: 9201 -> 9202
       Count distinct customers across the chain. /
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

Expected result:

Cart Recovery chain | 10
Flash Sale standalone | 7
Wave 2 chain | 5
TOTAL target_base | 22

23. Why Campaign 9004 Does Not Appear in the Final Result

Campaign 9004 does have communication-log rows.

The rows are:

C11
C12
C13
C14

So a naive query sees them.

However:

creation_status = approval_awaiting

This means the campaign has not cleared the approval workflow.

The reporting rule says that campaigns in this state do not contribute to the official reporting metric.

Therefore these four rows are intentionally excluded.

This is an important example of why querying only communication_log is insufficient.

The campaign table must also be joined to determine reporting eligibility.

24. Why Delivery Status Alone Is Not Used to Count the Final Metric

The communication_log table contains:

delivery_status

where:

900 = delivered
1100 = failed / soft failure

At first glance, it may seem reasonable to count only rows with:

delivery_status = 900

However, that would not implement the stated definition of target_base.

The metric is based on the number of distinct customers reached for an underlying communication, and failed attempts can be part of a retry chain that eventually succeeds.

For example:

C3

9001 -> delivery_status 1100
9002 -> delivery_status 1100
9003 -> delivery_status 900

The customer is still one underlying communication in the retry chain.

Therefore the retry chain needs to be treated as a unit rather than simply filtering individual attempts by delivery status.

25. Why COUNT(*) Alone Is Not Sufficient

The initial query:

COUNT(*)

is useful as an investigation starting point.

It tells us:

30 raw send rows

But it does not know:

- whether the campaign is eligible
- whether the campaign is a retry
- whether multiple rows represent the same underlying communication
- whether a repeated customer is a retry or a legitimate standalone re-target

Therefore COUNT(*) is a good baseline but not the final business metric.

26. Why COUNT(DISTINCT customer_id) Everywhere Is Also Not Sufficient

The opposite approach would be to count:

COUNT(DISTINCT customer_id)

for every campaign.

That also fails.

The clearest example is campaign 9101.

Its seven events involve six distinct customers because:

C20 appears twice

If we counted only distinct customers, we would get:

9101 = 6

But the campaign is standalone, and both C20 sends are legitimate independent events.

The correct count is:

9101 = 7

Therefore the correct logic must depend on campaign structure.

27. Business Logic Derived From the Data

The reconciliation demonstrates that there are effectively two different counting models.

Model A - Retry campaign family

For a retry chain:

A -> B -> C

the same customer appearing across A, B, and C represents the same underlying communication.

Therefore:

COUNT(DISTINCT customer_id)

across the entire chain is appropriate.

Model B - Standalone campaign

For a standalone campaign:

A

with no retry relationship, every send event is an independent event.

Therefore:

COUNT(*)

is appropriate.

This distinction is central to obtaining the correct result.

28. Investigation of the Cart Recovery Chain

The Cart Recovery family contains:

9001
9002
9003

with:

9002.parent_id = 9001
9003.parent_id = 9002

The data therefore establishes:

9001 -> 9002 -> 9003

There are 13 raw send attempts:

9001 = 10
9002 = 2
9003 = 1

Total:

13

But the unique customers across the chain are:

C1
C2
C3
C4
C5
C6
C7
C8
C9
C10

Therefore:

10 distinct customers

The three additional attempts are retries:

C2 second attempt
C3 second attempt
C3 third attempt

Thus:

13 raw attempts
-> 10 underlying customer communications

29. Investigation of the Wave 2 Chain

The Wave 2 family contains:

9201
9202

with:

9202.parent_id = 9201

Therefore:

9201 -> 9202

The raw send attempts are:

9201 = 5
9202 = 1

Total:

6

The customer list is:

D1
D2
D3
D4
D5
D1

D1 is present twice because the second send is a retry.

Therefore the underlying customers are:

D1
D2
D3
D4
D5

Final count:

5

30. Investigation of the Standalone Flash Sale

Campaign:

9101

has:

parent_id = NULL

It is therefore standalone.

The send events are:

C20
C20
C21
C22
C23
C24
C25

There are seven events.

Although C20 occurs twice, the second event is not represented by a new retry campaign.

It is therefore treated as a separate legitimate send event.

Final count:

7

31. Reconciliation From Raw Rows to Final Metric

The entire process can be summarized mathematically.

Starting point:

30 raw send rows

Remove the four rows from the ineligible campaign:

30 - 4 = 26

Correct the Cart Recovery retry chain:

13 raw rows -> 10 underlying customers

So:

26 - 3 = 23

Keep the seven standalone Flash Sale events:

23

Correct the Wave 2 retry chain:

6 raw rows -> 5 underlying customers

So:

23 - 1 = 22

Final:

22

32. Reconciliation Difference

Finance reported:

22

Our final SQL produces:

22

Therefore:

Finance value - calculated value

22 - 22 = 0

There is no remaining reconciliation difference.

33. What Surprised Me in the Data

One of the most surprising aspects of the data was that the communication log already contained send rows for campaign 9004 even though the campaign was still in approval_awaiting status. This means the send log cannot be treated as the complete definition of reporting eligibility by itself; the campaign lifecycle state also matters.

Another interesting observation was the difference between retry duplicates and legitimate repeated sends. For example, C3 appears across campaigns 9001, 9002, and 9003, where those campaigns form a retry chain. Those attempts represent one underlying communication and should therefore count once. In contrast, C20 appears twice under standalone campaign 9101, and both events should count because they are independent sends rather than retries. This distinction is what makes a blanket COUNT(DISTINCT customer_id) incorrect.

34. Key Data Quality / Modeling Observations

The analysis revealed several important characteristics of the data model.

Observation 1 - The communication log can contain records before reporting eligibility is finalized

Campaign 9004 has communication-log rows despite being:

approval_awaiting

Therefore reporting queries should not rely exclusively on the communication log.

Observation 2 - Retry relationships are represented structurally

The parent_id field is critical.

For example:

9002.parent_id = 9001
9003.parent_id = 9002
9202.parent_id = 9201

This allows retry chains to be identified.

Observation 3 - A retry is not equivalent to a duplicate row

A retry is a real send attempt, so it is correctly present in the raw log.

The issue is not that the row is invalid.

The issue is how the row should contribute to the business metric.

Observation 4 - Same-customer repetition is ambiguous without campaign context

A repeated customer can mean:

retry

or:

legitimate independent re-targeting

The campaign relationship must therefore be examined before deduplicating.

35. SQL Investigation Queries

The following queries were used during investigation.

35.1 Count all raw sends

SELECT COUNT(*) AS naive_send_count
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';

Expected result:

30

35.2 Compare send rows and distinct customers

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

This query helps identify where repeated customers occur.

35.3 Inspect campaign eligibility

SELECT
    id,
    merchant_id,
    parent_id,
    name,
    creation_status,
    processing_status
FROM campaign
WHERE merchant_id = 501
ORDER BY id;

This identifies the retry relationships and the pending campaign.

35.4 Inspect communication records

SELECT *
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01'
ORDER BY id;

This was useful for understanding individual customer-level behavior.

36. Reproducibility

The analysis is designed to be reproducible against the supplied SQLite database.

To open the database:

sqlite3 comm_log.db

Then:

.tables

To inspect the campaign schema:

.schema campaign

To inspect the communication log schema:

.schema communication_log

The final SQL can then be pasted directly into SQLite.

Alternatively, the query can be run directly from the command line:

sqlite3 comm_log.db "<SQL QUERY>"

The expected final result is:

Cart Recovery chain: 10
Flash Sale standalone: 7
Wave 2 chain: 5
TOTAL target_base: 22

37. Assumptions and Scope

The analysis follows the scope specified in the assignment:

merchant_id = 501

October 2026

communication_type = '2'

The date filter is implemented as:

sent_time >= '2026-10-01'
AND sent_time < '2026-11-01'

Using an inclusive start and exclusive end means all October timestamps are included while timestamps from November are excluded.

No additional merchants or communication types are included.

38. Why the Final Query Uses a Campaign Eligibility CTE

The final query begins with:

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
)

This creates a temporary set containing only campaigns that are eligible for reporting.

This is preferable to simply querying:

communication_log

because reporting eligibility is a property of the campaign.

The communication log tells us that a send happened.

The campaign table tells us whether the campaign qualifies for reporting.

Both pieces of information are therefore required.

39. Why the Final Query Uses Different Counting Methods

The final query intentionally does not use one universal aggregation rule.

For the Cart Recovery chain:

COUNT(DISTINCT cl.customer_id)

is used because multiple campaigns represent retries of the same underlying communication.

For Flash Sale:

COUNT(*)

is used because the campaign is standalone and each send is an independent event.

For Wave 2:

COUNT(DISTINCT cl.customer_id)

is used because the campaigns form a retry chain.

This is deliberate rather than inconsistent.

The different aggregation methods reflect the business definition of target_base.

40. Final Answer

The final reconciled value is:

target_base = 22

Detailed breakdown:

Cart Recovery retry chain: 10
Flash Sale standalone: 7
Wave 2 retry chain: 5

Total: 22

Finance reported:

22

Our analysis produces:

22

Therefore:

Reconciliation difference = 0

Final conclusion:

The Finance-reported target_base of 22 is correct.

The naive raw-row count of 30 overstates the metric because it includes four sends from an ineligible pending campaign and counts retry attempts as separate sends. Once campaign eligibility and retry-chain semantics are applied, while preserving legitimate repeated events from the standalone Flash Sale campaign, the result reconciles exactly to Finance's value of 22.

41. Files in This Submission

The submission contains the following analysis artifacts:

analysis.sql
README.md

analysis.sql contains the SQL investigation and final reconciliation query.

README.md documents the methodology, investigation steps, business rules, reconciliation bridge, and final result.

42. Final Reconciliation at a Glance

RAW DATA
   |
   v
30 communication rows
   |
   | Remove 9004
   | approval_awaiting
   v
26 eligible rows
   |
   +---------+---------+
   |                   |
   v                   v
Retry chains       Standalone
   |                   |
   |                   |
Deduplicate        Keep events
customers          independently
   |                   |
   v                   v
Cart = 10          Flash = 7
Wave = 5
   |                   |
   +---------+---------+
             |
             v
        10 + 7 + 5
             |
             v
        TARGET_BASE = 22
             |
             v
       Finance reported = 22
             |
             v
        Difference = 0

43. Final Statement

This analysis does not treat the communication_log as a simple table of independent customers. Instead, it combines:

1. campaign lifecycle eligibility
2. campaign parent/child relationships
3. retry-chain semantics
4. customer-level send history
5. and standalone campaign behavior

That combination is necessary to reproduce the reporting definition accurately.

The final result is:

22
