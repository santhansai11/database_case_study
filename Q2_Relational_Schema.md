# Q2 — Relational Schema (converted from the E-R Diagram)

## Conversion rules applied
- Strong entity → table with its primary key.
- 1:N relationship → foreign key on the **N** side.
- M:N relationship → separate **relation (junction table)** with the two PKs + relationship attributes.
- Weak entity (BATCH) → table whose PK includes the owner's keys.

## Schema (underlined = primary key, # = foreign key)

**Notation:** `EMP(emp_id, emp_name, ...)` — attribute underlined as `PK`, foreign key prefixed `FK:`

1. **PLANT** (<u>plant_id</u>, plant_name, location, annual_capacity)

2. **VEHICLE_MODEL** (<u>model_code</u>, model_name, vehicle_type, engine_capacity_cc, fuel_type, transmission, seating_capacity, ex_showroom_price)
   - CHECK: vehicle_type ∈ {Motorcycle, Scooter, Electric Scooter, Electric Motorcycle}

3. **COMPONENT** (<u>component_id</u>, component_name, category, unit_cost, is_critical)

4. **SUPPLIER** (<u>supplier_id</u>, supplier_name, address, supplier_type, rating)

5. **SUPPLIES** (<u>supplier_id</u>, <u>component_id</u>, unit_price, lead_time_days, quality_rating)
   - FK: supplier_id → SUPPLIER, component_id → COMPONENT   *(M:N resolved)*

6. **SUPPLY_ORDER** (<u>po_id</u>, supplier_id, component_id, qty_ordered, unit_price, order_date, delivery_date)
   - FK: supplier_id → SUPPLIER, component_id → COMPONENT

7. **BATCH** (<u>batch_no</u>, supplier_id, component_id, batch_qty, batch_date)
   - FK: (supplier_id, component_id) → SUPPLIES   *(batch_no is globally unique; batch tied to one supplier–component pair)*

8. **MODEL_COMPONENT** (BOM) (<u>model_code</u>, <u>component_id</u>, qty_per_vehicle)
   - FK: model_code → VEHICLE_MODEL, component_id → COMPONENT   *(M:N Uses)*

9. **VEHICLE** (<u>vin</u>, model_code, plant_id, mfg_date, color, status, dealer_id, customer_id, sale_date, sale_price)
   - FK: model_code → VEHICLE_MODEL, plant_id → PLANT, dealer_id → DEALER, customer_id → CUSTOMER
   - CHECK: status ∈ {In-Production, At-Plant, At-Dealer, Sold}

10. **VEHICLE_COMPONENT** (as-built) (<u>vin</u>, <u>component_id</u>, <u>batch_no</u>, install_date, serial_no)
    - FK: vin → VEHICLE, component_id → COMPONENT, batch_no → BATCH   *(M:N Fitted-With; enables defect recall)*

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

- **Total tables:** 18 (13 entities/relationships collapsed appropriately; 4 junction tables resolve the five M:N relationships).
- **Primary keys:** 18; **Composite PKs:** SUPPLIES, BATCH, MODEL_COMPONENT, VEHICLE_COMPONENT, PLANT_INVENTORY, DEALER_INVENTORY.
- **Foreign keys:** 24 referential-integrity constraints; ON DELETE RESTRICT used everywhere to protect history.
- **UNIQUE constraints:** CUSTOMER(phone), CUSTOMER(email), DEALER(phone) → no duplicate records.
- **CHECK constraints:** vehicle_type, vehicle status, claim status, fuel_type.
- Every problem from the case study maps to a construct:
  - *Track vehicle manufacturing → delivery* → VEHICLE(plant_id, dealer_id, customer_id, status)
  - *Duplicates* → UNIQUE constraints
  - *Components used in a vehicle / defective component recall* → VEHICLE_COMPONENT + BATCH
  - *Supplier performance* → SUPPLIES + SUPPLY_ORDER
  - *Inventory accuracy* → PLANT_INVENTORY / DEALER_INVENTORY
  - *Warranty & service history* → WARRANTY, WARRANTY_CLAIM, SERVICE_RECORD
  - *Production cost* → SUM(MODEL_COMPONENT.qty_per_vehicle × COMPONENT.unit_cost)
