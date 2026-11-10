import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker


# Fixed seeds and dates make the dataset reproducible.
rng = random.Random(42)
fake = Faker("en_US")
fake.seed_instance(42)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "data" / "generated"

START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 6, 30, 23, 59, 59)

CUSTOMER_COUNT = 100
RESTAURANT_COUNT = 10
ORDER_COUNT = 1000

LOCATIONS = [
    ("Detroit", "MI"),
    ("Chicago", "IL"),
    ("New York", "NY"),
    ("Austin", "TX"),
    ("Seattle", "WA"),
]

CUISINES = [
    "Indian",
    "Italian",
    "Mexican",
    "Chinese",
    "American",
]


def random_datetime(start, end):
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=rng.randint(0, seconds))


def format_datetime(value):
    return value.strftime("%Y-%m-%d %H:%M:%S")


def write_csv(filename, rows):
    path = OUTPUT_DIR / filename

    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    print(f"Created {filename}: {len(rows):,} rows")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    customers = []
    restaurants = []
    orders = []

    # Create customers before creating their orders.
    for customer_id in range(1, CUSTOMER_COUNT + 1):
        city, state = rng.choice(LOCATIONS)
        registered = random_datetime(
            START_DATE,
            datetime(2026, 3, 31, 23, 59, 59),
        )

        customers.append({
            "customer_id": customer_id,
            "first_name": fake.first_name(),
            "last_name": fake.last_name(),
            "email": f"customer{customer_id}@example.com",
            "city": city,
            "state": state,
            "registration_date": registered.strftime("%Y-%m-%d"),
            "updated_at": format_datetime(registered),
        })

    for restaurant_id in range(1, RESTAURANT_COUNT + 1):
        city, state = rng.choice(LOCATIONS)

        restaurants.append({
            "restaurant_id": restaurant_id,
            "restaurant_name": f"Demo Kitchen {restaurant_id:02d}",
            "cuisine_type": rng.choice(CUISINES),
            "city": city,
            "state": state,
            "is_active": 1,
            "updated_at": format_datetime(START_DATE),
        })

    for order_id in range(1, ORDER_COUNT + 1):
        customer = rng.choice(customers)

        # Match customers to restaurants in their city.
        local_restaurants = [
            restaurant
            for restaurant in restaurants
            if restaurant["city"] == customer["city"]
        ]

        # Create an explicit fallback for cities without a restaurant.
        if not local_restaurants:
            local_restaurants = restaurants

        restaurant = rng.choice(local_restaurants)

        registered = datetime.strptime(
            customer["updated_at"],
            "%Y-%m-%d %H:%M:%S",
        )

        order_date = random_datetime(registered, END_DATE)

        status = rng.choices(
            ["Completed", "Cancelled", "Pending"],
            weights=[85, 10, 5],
            k=1,
        )[0]

        payment_status = {
            "Completed": "Paid",
            "Cancelled": "Unpaid",
            "Pending": "Pending",
        }[status]

        amount_cents = rng.randint(800, 12000)

        orders.append({
            "order_id": order_id,
            "customer_id": customer["customer_id"],
            "restaurant_id": restaurant["restaurant_id"],
            "order_date": format_datetime(order_date),
            "order_status": status,
            "payment_status": payment_status,
            "total_amount": (
                f"{amount_cents // 100}.{amount_cents % 100:02d}"
            ),
            "updated_at": format_datetime(order_date),
        })

    # Basic checks before writing the dataset.
    customer_ids = {row["customer_id"] for row in customers}
    restaurant_ids = {row["restaurant_id"] for row in restaurants}

    assert len({row["order_id"] for row in orders}) == ORDER_COUNT
    assert all(row["customer_id"] in customer_ids for row in orders)
    assert all(row["restaurant_id"] in restaurant_ids for row in orders)

    write_csv("customers.csv", customers)
    write_csv("restaurants.csv", restaurants)
    write_csv("orders.csv", orders)

    print("\nBasic checks passed.")
    print(f"Files saved in: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()