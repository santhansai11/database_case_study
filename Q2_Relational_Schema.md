# Q2 — Relational Schema (converted from the E-R Diagram)

## Conversion rules applied
- Strong entity → table with its primary key.
- 1:N relationship → foreign key on the **N** side.
- M:N relationship → separate **relation (junction table)** with the parent keys and relationship attributes. Use a surrogate key when the same pair can occur repeatedly, as with individual fitted parts.
- BATCH and SERVICE_RECORD have their own complete keys and are strong entities, although their existence depends on parent records. BATCH uses a globally unique internal `batch_no`; its supplier/component pair is a foreign key to SUPPLIES.

## Schema (underlined = primary key, # = foreign key)

**Notation:** `EMP(emp_id, emp_name, ...)` — attribute underlined as `PK`, foreign key prefixed `FK:`

1. **PLANT** (<u>plant_id</u>, plant_name, location, annual_capacity)

2. **VEHICLE_MODEL** (<u>model_code</u>, model_name, vehicle_type, engine_capacity_cc, fuel_type, transmission, seating_capacity, ex_showroom_price)
   - CHECK: vehicle_type ∈ {Motorcycle, Scooter, Electric Scooter, Electric Motorcycle}
   - Petrol models must be Motorcycle/Scooter with positive engine capacity; electric types must use Electric fuel and NULL engine capacity.

3. **COMPONENT** (<u>component_id</u>, component_name, category, unit_cost, is_critical)

4. **SUPPLIER** (<u>supplier_id</u>, supplier_name, address, supplier_type, rating)

5. **SUPPLIES** (<u>supplier_id</u>, <u>component_id</u>, unit_price, lead_time_days, quality_rating)
   - FK: supplier_id → SUPPLIER, component_id → COMPONENT   *(M:N resolved)*

6. **SUPPLY_ORDER** (<u>po_id</u>, supplier_id, component_id, qty_ordered, unit_price, order_date, agreed_lead_time_days, delivery_date)
   - FK: supplier_id → SUPPLIER, component_id → COMPONENT, (supplier_id, component_id) → SUPPLIES
   - CHECK: unit_price and agreed_lead_time_days ≥ 0; delivery_date is NULL or ≥ order_date. The agreed lead time is stored on the order, independently of later changes to SUPPLIES.

7. **BATCH** (<u>batch_no</u>, supplier_id, component_id, batch_qty, batch_date)
   - FK: (supplier_id, component_id) → SUPPLIES   *(batch_no is globally unique; batch tied to one supplier–component pair)*

8. **MODEL_COMPONENT** (BOM) (<u>model_code</u>, <u>component_id</u>, qty_per_vehicle)
   - FK: model_code → VEHICLE_MODEL, component_id → COMPONENT   *(M:N Uses)*

9. **VEHICLE** (<u>vin</u>, model_code, plant_id, mfg_date, color, status, dealer_id, customer_id, sale_date, sale_price)
   - FK: model_code → VEHICLE_MODEL, plant_id → PLANT, dealer_id → DEALER, customer_id → CUSTOMER
   - CHECK: status ∈ {In-Production, At-Plant, At-Dealer, Sold}

10. **VEHICLE_COMPONENT** (as-built) (<u>fitment_id</u>, vin, component_id, batch_no, install_date, serial_no)
    - FK: vin → VEHICLE, component_id → COMPONENT, (batch_no, component_id) → BATCH(batch_no, component_id)
    - One row per physical part in the original build; repeated component types and different batches on the same vehicle are allowed.
    - UNIQUE: (component_id, serial_no), assuming serials are unique within a component type. Multiple NULL serials allow unnumbered parts. BATCH has UNIQUE(batch_no, component_id) to support the composite foreign key.

11. **PLANT_INVENTORY** (<u>plant_id</u>, <u>component_id</u>, qty_on_hand, reorder_level)
    - FK: plant_id → PLANT, component_id → COMPONENT

12. **DEALER** (<u>dealer_id</u>, dealer_name, address, city, phone UNIQUE)

13. **DEALER_INVENTORY** (<u>dealer_id</u>, <u>component_id</u>, qty_on_hand, reorder_level)
    - FK: dealer_id → DEALER, component_id → COMPONENT

14. **EMPLOYEE** (<u>emp_id</u>, emp_name, designation, salary, hire_date, plant_id)
    - FK: plant_id → PLANT   *(N:1 Works-At moved into EMPLOYEE)*

15. **CUSTOMER** (<u>customer_id</u>, customer_name, phone UNIQUE, email UNIQUE, address)

16. **SERVICE_RECORD** (<u>service_id</u>, vin, emp_id, service_date, service_type, odometer_km, cost, remarks)
    - FK: vin → VEHICLE, emp_id → EMPLOYEE

17. **WARRANTY** (<u>warranty_id</u>, vin, warranty_type, start_date, end_date)
    - FK: vin → VEHICLE

18. **WARRANTY_CLAIM** (<u>claim_id</u>, warranty_id, claim_date, defect_description, status, claim_amount, resolution)
    - FK: warranty_id → WARRANTY

## Key/Referential-Integrity Summary

- **Total tables:** 18. The five M:N relationships become junction tables: SUPPLIES, MODEL_COMPONENT, VEHICLE_COMPONENT, PLANT_INVENTORY, and DEALER_INVENTORY.
- **Implemented relationships:** 24 foreign-key constraints. Composite foreign keys count once each. Q1 Section 3 lists all 24 links, and the detailed crow's-foot source uses the same numbers; 18 is the table count, not the relationship count.
- **Primary keys:** 18; **Composite PKs:** SUPPLIES, MODEL_COMPONENT, PLANT_INVENTORY, DEALER_INVENTORY. BATCH uses `batch_no`; VEHICLE_COMPONENT uses `fitment_id`.
- **Foreign keys:** actions match `Q3_two_wheeler_db.sql`. History that must be kept (supply orders, batches, vehicles, dealers, and the component/batch side of fitment) uses `ON DELETE RESTRICT`. Rows that belong to a parent (supplies, inventories, service, warranty, claims, and the vehicle side of fitment) use `ON DELETE CASCADE`. `service_record.emp_id` uses `ON DELETE SET NULL`. A supply order and a batch must reference a real SUPPLIES pair. A fitted part must reference a batch of that same component.
- **UNIQUE constraints:** CUSTOMER(phone), CUSTOMER(email), DEALER(phone), VEHICLE_COMPONENT(component_id, serial_no), BATCH(batch_no, component_id). Contact uniqueness assumes customers/dealers use distinct contact identifiers; it does not prove that records with different contacts represent different people.
- **Domains and checks:** ENUM domains constrain statuses and types. CHECKs enforce fuel/type/engine agreement, positive sale prices, sale dates against status and manufacture date, delivery chronology, nonnegative order prices and lead times, quantities and ratings. MySQL 8.0.16+ is required. MySQL prohibits the configured foreign-key actions on columns used in CHECKs, so INSERT/UPDATE triggers enforce dealer/customer presence: Sold needs both, At-Dealer needs only a dealer, and a vehicle still at the plant needs neither.
- Every problem from the case study maps to a construct:
  - *Track vehicle manufacturing → delivery* → VEHICLE(plant_id, dealer_id, customer_id, status)
  - *Duplicates* → UNIQUE constraints
  - *Components used in a vehicle / defective component recall* → VEHICLE_COMPONENT + BATCH
  - *Supplier performance* → SUPPLIES + SUPPLY_ORDER
  - *Inventory accuracy* → PLANT_INVENTORY / DEALER_INVENTORY
  - *Warranty & service history* → WARRANTY, WARRANTY_CLAIM, SERVICE_RECORD
  - *Material cost estimate* → SUM(MODEL_COMPONENT.qty_per_vehicle × COMPONENT.unit_cost); labour and overhead are outside this estimate.
