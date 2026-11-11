import csv
import random
from pathlib import Path

SEED = 20261111
ROW_COUNT = 10_000
OUT_DIR = Path(__file__).resolve().parent
RAW_PATH = OUT_DIR / "customers_raw.csv"
CLEAN_PATH = OUT_DIR / "customers_clean.csv"
FIELDS = [
    "record_id", "customer_id", "customer_name", "email", "age", "city",
    "signup_date", "annual_income", "membership", "last_purchase_date", "notes",
]
FIRST_NAMES = ["Aarav", "Ananya", "Diya", "Ishaan", "Kavya", "Meera", "Neel", "Rohan", "Sana", "Vivaan", "Ira", "Arjun", "Mira", "Kabir", "Tara"]
LAST_NAMES = ["Das", "Sen", "Sharma", "Roy", "Patel", "Khan", "Iyer", "Gupta", "Dutta", "Nair", "Bose", "Reddy"]
CITIES = ["Kolkata", "Delhi", "Mumbai", "Chennai", "Bengaluru", "Hyderabad", "Pune", "Jaipur", "Bhopal", "Guwahati"]
MEMBERSHIPS = ["Basic", "Silver", "Gold", "Platinum"]


def maybe_dirty(value, rng, blank_rate=0.0):
    if rng.random() < blank_rate:
        return ""
    return value


def generate():
    rng = random.Random(SEED)
    raw_rows = []
    # Each group of five rows refers to one customer, creating 2,000 duplicate groups.
    for record_id in range(1, ROW_COUNT + 1):
        customer_id = ((record_id - 1) // 5) + 1
        first = FIRST_NAMES[(customer_id * 7) % len(FIRST_NAMES)]
        last = LAST_NAMES[(customer_id * 11) % len(LAST_NAMES)]
        name = f"{first} {last}"
        email = f"{first.lower()}.{last.lower()}{customer_id:04d}@example.com"
        age = str(18 + (customer_id * 13) % 58)
        city = CITIES[(customer_id * 3) % len(CITIES)]
        month = 1 + (customer_id % 12)
        day = 1 + (customer_id * 7 % 27)
        signup = f"2024-{month:02d}-{day:02d}"
        income = str(25000 + (customer_id * 1379) % 175000)
        membership = MEMBERSHIPS[customer_id % len(MEMBERSHIPS)]
        last_month = 1 + ((customer_id + 5) % 12)
        last_purchase = f"2025-{last_month:02d}-{day:02d}"
        note = f"Synthetic practice customer {customer_id}; batch {1 + customer_id % 8}"

        # Deliberate issues for practicing SQL cleaning.
        if record_id % 17 == 0:
            name = f"  {name.upper()}  "
        elif record_id % 19 == 0:
            name = f"{name.lower()} "
        if record_id % 23 == 0:
            email = f" {email.upper()} "
        if record_id % 29 == 0:
            city = f" {city.upper()} "
        if record_id % 31 == 0:
            membership = membership.upper() if record_id % 62 == 0 else f" {membership.lower()} "
        if record_id % 43 == 0:
            age = "unknown"
        if record_id % 47 == 0:
            signup = "not-a-date"
        if record_id % 53 == 0:
            income = "not-provided"
        if record_id % 11 == 0:
            email = ""
        else:
            email = maybe_dirty(email, rng, 0.002)
        name = maybe_dirty(name, rng, 0.003)
        city = maybe_dirty(city, rng, 0.025)
        membership = maybe_dirty(membership, rng, 0.01)
        if record_id % 13 == 0:
            last_purchase = ""
        raw_rows.append({
            "record_id": str(record_id), "customer_id": str(customer_id),
            "customer_name": name, "email": email, "age": age, "city": city,
            "signup_date": signup, "annual_income": income,
            "membership": membership, "last_purchase_date": last_purchase,
            "notes": note,
        })

    with RAW_PATH.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\r\n", quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(raw_rows)

    # Mirror the SQL cleaning rule: normalize email first, keep earliest record for each
    # nonblank normalized email; retain blank-email rows for manual review.
    seen_emails = set()
    clean_rows = []
    for row in raw_rows:
        email_key = row["email"].strip().lower()
        if email_key:
            if email_key in seen_emails:
                continue
            seen_emails.add(email_key)
        name = " ".join(row["customer_name"].split()).lower()
        name = name[:1].upper() + name[1:]
        city = " ".join(row["city"].split()).lower()
        city = city[:1].upper() + city[1:]
        membership = row["membership"].strip().title()
        age_value = row["age"].strip()
        age = age_value if age_value.isdigit() and 0 <= int(age_value) <= 120 else ""
        income_value = row["annual_income"].strip()
        income = income_value if income_value.isdigit() else ""
        signup = row["signup_date"] if len(row["signup_date"]) == 10 and row["signup_date"][4:5] == "-" and row["signup_date"][7:8] == "-" else ""
        clean_rows.append({
            **row,
            "customer_name": name,
            "email": email_key,
            "age": age,
            "city": city,
            "signup_date": signup,
            "annual_income": income,
            "membership": membership,
            "last_purchase_date": row["last_purchase_date"].strip(),
            "notes": " ".join(row["notes"].split()),
        })

    with CLEAN_PATH.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\r\n", quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(clean_rows)
    print(f"Created {RAW_PATH.name}: {len(raw_rows):,} rows")
    print(f"Created {CLEAN_PATH.name}: {len(clean_rows):,} rows")


if __name__ == "__main__":
    generate()


