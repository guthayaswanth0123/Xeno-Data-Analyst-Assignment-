"""
Generates the synthetic raw dataset for the comm-log reconciliation take-home.

Produces two tables, loaded into a SQLite DB (data/comm_log.db) and also
written as CSVs (data/campaign.csv, data/communication_log.csv):

  campaign(id, merchant_id, parent_id, name, creation_status, processing_status)
  communication_log(id, merchant_id, communication_id, customer_id,
                     communication_type, delivery_status, sent_time,
                     scheduled_time, credit_used, channel)

Scenario: merchant_id=501, October 2026, two campaign "families" that retry
(chain via campaign.parent_id), one ineligible retry branch, and one
standalone ("leaf") campaign with a legitimately repeated customer send.

This script only WRITES the raw data. It does not compute any aggregate or
target number — see compute_ground_truth.py for the independent
reconciliation, run separately against this same output.
"""

import csv
import sqlite3
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(exist_ok=True)

MERCHANT_ID = 501

# --- campaign table -----------------------------------------------------
# creation_status/processing_status mirror the real eligibility gate:
# eligible = creation_status IN ('approved','aborted','resumed','stopped')
#            AND processing_status = 'processed'
campaigns = [
    # id,   parent_id, name,                                  creation_status,   processing_status
    (9001, None, "Diwali Cart Recovery - Wave 1",              "approved",        "processed"),
    (9002, 9001, "Diwali Cart Recovery - Retry A",              "approved",        "processed"),
    (9003, 9002, "Diwali Cart Recovery - Retry B",              "approved",        "processed"),
    (9004, 9001, "Diwali Cart Recovery - Retry C (pending)",    "approval_awaiting", "processed"),
    (9101, None, "Diwali Flash Sale - Standalone",              "approved",        "processed"),
    (9201, None, "Diwali Wave 2",                               "approved",        "processed"),
    (9202, 9201, "Diwali Wave 2 - Retry",                       "approved",        "processed"),
]

# --- communication_log rows ---------------------------------------------
# Each tuple: (communication_id, customer_id, delivery_status, sent_time)
# delivery_status: 900 = delivered (best), 1100 = failed (soft, retryable)
rows = []
_next_id = [1]


def log_row(communication_id, customer_id, delivery_status, sent_time, credit_used=1):
    rid = _next_id[0]
    _next_id[0] += 1
    rows.append(
        (
            rid,
            MERCHANT_ID,
            communication_id,
            customer_id,
            "2",  # communication_type: Campaign
            delivery_status,
            sent_time,
            sent_time,  # scheduled_time == sent_time for this synthetic set
            credit_used,
            "sms",
        )
    )


# Family A: 9001 -> 9002 -> 9003, 10 customers (C1..C10)
log_row(9001, "C1", 900, "2026-10-03 10:00:00")
log_row(9001, "C2", 1100, "2026-10-03 10:00:00")
log_row(9002, "C2", 900, "2026-10-04 10:00:00")
log_row(9001, "C3", 1100, "2026-10-03 10:00:00")
log_row(9002, "C3", 1100, "2026-10-04 10:00:00")
log_row(9003, "C3", 900, "2026-10-05 10:00:00")
for i in range(4, 11):  # C4..C10
    log_row(9001, f"C{i}", 900, "2026-10-03 10:00:00")

# Ineligible retry branch: 9004 (approval_awaiting) — 4 customers
for i in range(11, 15):  # C11..C14
    log_row(9004, f"C{i}", 900, "2026-10-06 10:00:00")

# Standalone leaf: 9101 — C20 legitimately re-targeted twice, C21..C25 once
log_row(9101, "C20", 900, "2026-10-10 10:00:00")
log_row(9101, "C20", 900, "2026-10-20 10:00:00")
for i in range(21, 26):  # C21..C25
    log_row(9101, f"C{i}", 900, "2026-10-10 10:00:00")

# Family B: 9201 -> 9202, 5 customers (D1..D5)
log_row(9201, "D1", 1100, "2026-10-07 10:00:00")
log_row(9202, "D1", 900, "2026-10-08 10:00:00")
for i in range(2, 6):  # D2..D5
    log_row(9201, f"D{i}", 900, "2026-10-07 10:00:00")


def write_csvs():
    with open(DATA_DIR / "campaign.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "merchant_id", "parent_id", "name", "creation_status", "processing_status"])
        for cid, parent_id, name, creation_status, processing_status in campaigns:
            w.writerow([cid, MERCHANT_ID, parent_id if parent_id is not None else "", name, creation_status, processing_status])

    with open(DATA_DIR / "communication_log.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "id", "merchant_id", "communication_id", "customer_id",
                "communication_type", "delivery_status", "sent_time",
                "scheduled_time", "credit_used", "channel",
            ]
        )
        for r in rows:
            w.writerow(r)


def write_sqlite():
    db_path = DATA_DIR / "comm_log.db"
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute(
        """
        create table campaign (
            id integer primary key,
            merchant_id integer not null,
            parent_id integer,
            name text not null,
            creation_status text not null,
            processing_status text not null
        )
        """
    )
    cur.execute(
        """
        create table communication_log (
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
        )
        """
    )
    cur.executemany(
        "insert into campaign values (?,?,?,?,?,?)",
        [(cid, MERCHANT_ID, parent_id, name, cs, ps) for cid, parent_id, name, cs, ps in campaigns],
    )
    cur.executemany("insert into communication_log values (?,?,?,?,?,?,?,?,?,?)", rows)
    conn.commit()
    conn.close()


if __name__ == "__main__":
    write_csvs()
    write_sqlite()
    print(f"Wrote {len(campaigns)} campaign rows, {len(rows)} communication_log rows to {DATA_DIR}")
