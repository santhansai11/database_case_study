-- ============================================================================
-- Q3 : Integrated Two-Wheeler Manufacturing Database Management System
-- Set-B Case Study | MySQL 8.0.16+ (CHECK constraints must be enforced)
-- PostgreSQL requires a separate port of identity columns, ENUMs and triggers.
-- Run order: whole file top-to-bottom:  mysql -u root -p < Q3_two_wheeler_db.sql
-- ============================================================================

DROP DATABASE IF EXISTS two_wheeler_db;
CREATE DATABASE two_wheeler_db CHARACTER SET utf8mb4;
USE two_wheeler_db;

-- ----------------------------------------------------------------------------
-- 1. Core entities
-- ----------------------------------------------------------------------------
CREATE TABLE plant (
    plant_id        INT AUTO_INCREMENT PRIMARY KEY,
    plant_name      VARCHAR(60)  NOT NULL,
    location        VARCHAR(80)  NOT NULL,
    annual_capacity INT NOT NULL CHECK (annual_capacity > 0)
);

CREATE TABLE vehicle_model (
    model_code         VARCHAR(10) PRIMARY KEY,          -- e.g. 'XSP160'
    model_name         VARCHAR(60) NOT NULL,             -- e.g. 'X-Sport 160'
    vehicle_type       ENUM('Motorcycle','Scooter','Electric Scooter','Electric Motorcycle') NOT NULL,
    engine_capacity_cc INT NULL,                          -- NULL for electric
    fuel_type          ENUM('Petrol','Electric') NOT NULL,
    transmission       VARCHAR(20) NOT NULL,              -- '5-Speed', 'CVT', ...
    seating_capacity   INT NOT NULL CHECK (seating_capacity BETWEEN 1 AND 3),
    ex_showroom_price  DECIMAL(12,2) NOT NULL CHECK (ex_showroom_price > 0),
    CHECK (
        (vehicle_type IN ('Motorcycle','Scooter') AND fuel_type = 'Petrol'
            AND engine_capacity_cc IS NOT NULL AND engine_capacity_cc > 0)
        OR (vehicle_type IN ('Electric Scooter','Electric Motorcycle')
            AND fuel_type = 'Electric' AND engine_capacity_cc IS NULL)
    )
);

CREATE TABLE component (
    component_id   INT AUTO_INCREMENT PRIMARY KEY,
    component_name VARCHAR(60) NOT NULL,               -- Engine, Battery, ECU...
    category       VARCHAR(40) NOT NULL,               -- Engine/Electrical/Brakes...
    unit_cost      DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
    is_critical    BOOLEAN NOT NULL DEFAULT FALSE      -- TRUE => serial/batch tracked
);

CREATE TABLE supplier (
    supplier_id   INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(60) NOT NULL,
    address       VARCHAR(120) NOT NULL,
    supplier_type ENUM('OEM','Aftermarket','Raw-Material') NOT NULL,
    rating        DECIMAL(2,1) CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE employee (
    emp_id      INT AUTO_INCREMENT PRIMARY KEY,
    emp_name    VARCHAR(60) NOT NULL,
    designation ENUM('Assembly Worker','Quality Inspector','Mechanic','Supervisor','Manager','Sales Executive','Service Advisor') NOT NULL,
    salary      DECIMAL(10,2) NOT NULL CHECK (salary > 0),
    hire_date   DATE NOT NULL,
    plant_id    INT NOT NULL,                          -- N:1 Works-At
    CONSTRAINT fk_emp_plant FOREIGN KEY (plant_id) REFERENCES plant (plant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE dealer (
    dealer_id   INT AUTO_INCREMENT PRIMARY KEY,
    dealer_name VARCHAR(60) NOT NULL,
    address     VARCHAR(120) NOT NULL,
    city        VARCHAR(40) NOT NULL,
    phone       VARCHAR(15) NOT NULL UNIQUE             -- avoids duplicate dealers
);

CREATE TABLE customer (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(60) NOT NULL,
    phone         VARCHAR(15) NOT NULL UNIQUE,           -- avoids duplicate customers
    email         VARCHAR(80) UNIQUE,
    address       VARCHAR(120) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. Supplier -- Component relationships (M:N + ordering history)
-- ----------------------------------------------------------------------------
CREATE TABLE supplies (                                -- M:N relationship
    supplier_id    INT NOT NULL,
    component_id   INT NOT NULL,
    unit_price     DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    lead_time_days INT NOT NULL CHECK (lead_time_days >= 0),
    quality_rating DECIMAL(2,1) CHECK (quality_rating BETWEEN 0 AND 5),
    PRIMARY KEY (supplier_id, component_id),
    FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE supply_order (                            -- supply history -> performance
    po_id         INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id   INT NOT NULL,
    component_id  INT NOT NULL,
    qty_ordered   INT NOT NULL CHECK (qty_ordered > 0),
    unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    order_date    DATE NOT NULL,
    agreed_lead_time_days INT NOT NULL CHECK (agreed_lead_time_days >= 0),
    delivery_date DATE NULL,                             -- NULL => not delivered yet
    CHECK (delivery_date IS NULL OR delivery_date >= order_date),
    FOREIGN KEY (supplier_id)  REFERENCES supplier (supplier_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (supplier_id, component_id) REFERENCES supplies (supplier_id, component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 3. BATCH : strong entity with its own key -> enables defect tracing
--    batch_no is a globally unique internal lot code; the batch belongs to
--    one (supplier, component) pair, enforced via FK to SUPPLIES.
-- ----------------------------------------------------------------------------
CREATE TABLE batch (
    batch_no     VARCHAR(20) PRIMARY KEY,
    supplier_id  INT NOT NULL,
    component_id INT NOT NULL,
    batch_qty    INT NOT NULL CHECK (batch_qty > 0),
    batch_date   DATE NOT NULL,
    UNIQUE KEY uq_batch_component (batch_no, component_id),
    FOREIGN KEY (supplier_id, component_id) REFERENCES supplies (supplier_id, component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 4. Bill of Materials : VEHICLE_MODEL -- M:N -- COMPONENT
-- ----------------------------------------------------------------------------
CREATE TABLE model_component (
    model_code      VARCHAR(10) NOT NULL,
    component_id    INT NOT NULL,
    qty_per_vehicle INT NOT NULL CHECK (qty_per_vehicle > 0),
    PRIMARY KEY (model_code, component_id),
    FOREIGN KEY (model_code) REFERENCES vehicle_model (model_code)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 5. VEHICLE : manufactured at plant, of a model, sold via dealer to customer
-- ----------------------------------------------------------------------------
CREATE TABLE vehicle (
    vin          VARCHAR(17) PRIMARY KEY,                -- chassis number
    model_code   VARCHAR(10) NOT NULL,
    plant_id     INT NOT NULL,
    mfg_date     DATE NOT NULL,
    color        VARCHAR(20) NOT NULL,
    status       ENUM('In-Production','At-Plant','At-Dealer','Sold') NOT NULL DEFAULT 'In-Production',
    dealer_id    INT NULL,                               -- set when shipped to dealer
    customer_id  INT NULL,                               -- set when sold
    sale_date    DATE NULL,
    sale_price   DECIMAL(12,2) NULL CHECK (sale_price > 0),
    FOREIGN KEY (model_code) REFERENCES vehicle_model (model_code)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (plant_id)   REFERENCES plant (plant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (dealer_id)  REFERENCES dealer (dealer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (
        (status = 'Sold'
            AND sale_date IS NOT NULL AND sale_price IS NOT NULL
            AND sale_date >= mfg_date)
        OR (status <> 'Sold'
            AND sale_date IS NULL AND sale_price IS NULL)
    )
);

-- dealer_id and customer_id cannot appear in that CHECK: MySQL forbids a CHECK
-- on a column that also has a foreign-key action. The trigger enforces them.
DELIMITER //
CREATE TRIGGER trg_vehicle_bi BEFORE INSERT ON vehicle
FOR EACH ROW
BEGIN
    IF NEW.status = 'Sold' AND (NEW.dealer_id IS NULL OR NEW.customer_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A sold vehicle needs a dealer and a customer';
    END IF;
    IF NEW.status = 'At-Dealer' AND (NEW.dealer_id IS NULL OR NEW.customer_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle at a dealer needs a dealer and no customer';
    END IF;
    IF NEW.status IN ('In-Production', 'At-Plant')
       AND (NEW.dealer_id IS NOT NULL OR NEW.customer_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle at the plant cannot have a dealer or a customer';
    END IF;
END//
CREATE TRIGGER trg_vehicle_bu BEFORE UPDATE ON vehicle
FOR EACH ROW
BEGIN
    IF NEW.status = 'Sold' AND (NEW.dealer_id IS NULL OR NEW.customer_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A sold vehicle needs a dealer and a customer';
    END IF;
    IF NEW.status = 'At-Dealer' AND (NEW.dealer_id IS NULL OR NEW.customer_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle at a dealer needs a dealer and no customer';
    END IF;
    IF NEW.status IN ('In-Production', 'At-Plant')
       AND (NEW.dealer_id IS NOT NULL OR NEW.customer_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle at the plant cannot have a dealer or a customer';
    END IF;
END//
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 6. As-built fitment : VEHICLE -- M:N -- COMPONENT (via batch)
-- ----------------------------------------------------------------------------
CREATE TABLE vehicle_component (
    fitment_id   INT AUTO_INCREMENT PRIMARY KEY,
    vin          VARCHAR(17) NOT NULL,
    component_id INT NOT NULL,
    batch_no     VARCHAR(20) NOT NULL,
    install_date DATE NOT NULL,
    serial_no    VARCHAR(30) NULL,                       -- for critical parts
    -- One row per physical part in the original build, including repeated tyres.
    -- Serial numbers are unique within a component type; NULL allows unnumbered parts.
    UNIQUE KEY uq_component_serial (component_id, serial_no),
    FOREIGN KEY (vin)          REFERENCES vehicle (vin)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (batch_no, component_id) REFERENCES batch (batch_no, component_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 7. Inventory at plants and dealers (M:N with qty + reorder level)
-- ----------------------------------------------------------------------------
CREATE TABLE plant_inventory (
    plant_id      INT NOT NULL,
    component_id  INT NOT NULL,
    qty_on_hand   INT NOT NULL CHECK (qty_on_hand >= 0),
    reorder_level INT NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    PRIMARY KEY (plant_id, component_id),
    FOREIGN KEY (plant_id)     REFERENCES plant (plant_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE dealer_inventory (
    dealer_id     INT NOT NULL,
    component_id  INT NOT NULL,
    qty_on_hand   INT NOT NULL CHECK (qty_on_hand >= 0),
    reorder_level INT NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    PRIMARY KEY (dealer_id, component_id),
    FOREIGN KEY (dealer_id)    REFERENCES dealer (dealer_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (component_id) REFERENCES component (component_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 8. Service history, Warranty and Claims
-- ----------------------------------------------------------------------------
CREATE TABLE service_record (
    service_id   INT AUTO_INCREMENT PRIMARY KEY,
    vin          VARCHAR(17) NOT NULL,
    emp_id       INT NULL,                               -- mechanic who serviced
    service_date DATE NOT NULL,
    service_type ENUM('Free','Paid','Recall','Repair') NOT NULL,
    odometer_km  INT NOT NULL CHECK (odometer_km >= 0),
    cost         DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    remarks      VARCHAR(200),
    FOREIGN KEY (vin)    REFERENCES vehicle (vin)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (emp_id) REFERENCES employee (emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE warranty (
    warranty_id   INT AUTO_INCREMENT PRIMARY KEY,
    vin           VARCHAR(17) NOT NULL,
    warranty_type ENUM('Standard','Extended') NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    CHECK (end_date > start_date),
    FOREIGN KEY (vin) REFERENCES vehicle (vin)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE warranty_claim (
    claim_id           INT AUTO_INCREMENT PRIMARY KEY,
    warranty_id        INT NOT NULL,
    claim_date         DATE NOT NULL,
    defect_description VARCHAR(200) NOT NULL,
    status             ENUM('Open','Approved','Rejected','Resolved') NOT NULL DEFAULT 'Open',
    claim_amount       DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (claim_amount >= 0),
    resolution         VARCHAR(200),
    FOREIGN KEY (warranty_id) REFERENCES warranty (warranty_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- INSERT RECORDS (Part 1 : master data)
-- ============================================================================
INSERT INTO plant (plant_name, location, annual_capacity) VALUES
('Hosur Plant',     'Hosur, Tamil Nadu',    300000),
('Manesar Plant',   'Manesar, Haryana',     250000),
('Chakan Plant',    'Chakan, Maharashtra',  200000),
('Bidadi EV Plant', 'Bidadi, Karnataka',    100000);

INSERT INTO vehicle_model VALUES
('XSP160','X-Sport 160','Motorcycle',160,'Petrol','5-Speed',2,125000.00),
('ZMR2100','Z-Mileage 210','Motorcycle',210,'Petrol','5-Speed',2,148500.00),
('SCT1100','S-City 110','Scooter',110,'Petrol','CVT',2,87999.00),
('EVX3000','EV-X 3.0','Electric Scooter',NULL,'Electric','Hub Motor',2,112000.00),
('EVM5000','EV-Moto 5','Electric Motorcycle',NULL,'Electric','1-Speed',2,165000.00);

INSERT INTO component (component_name, category, unit_cost, is_critical) VALUES
('Engine Assembly 160cc','Engine',22000.00,TRUE),
('Engine Assembly 210cc','Engine',27500.00,TRUE),
('Li-Ion Battery Pack 3kWh','Electrical',26000.00,TRUE),
('ECU','Electrical',4500.00,TRUE),
('Brake Assembly (Disc)','Brakes',3800.00,FALSE),
('Tyre 90/90-17','Wheels',2100.00,FALSE),
('Wheel Rim Alloy','Wheels',2900.00,FALSE),
('Headlamp LED','Electrical',1600.00,FALSE),
('Clutch Assembly','Transmission',3200.00,FALSE),
('Suspension Fork','Chassis',5100.00,FALSE),
('Controller (Motor Driver)','Electrical',8200.00,TRUE),
('Hub Motor 3kW','Electrical',15500.00,TRUE),
('Engine Assembly 110cc','Engine',16000.00,TRUE);

INSERT INTO supplier (supplier_name, address, supplier_type, rating) VALUES
('Bharat Brakes Pvt Ltd','Plot 12, Peenya, Bengaluru','OEM',4.5),
('Sunridges Tyres Ltd','Chakan MIDC, Pune','OEM',4.2),
('VoltCells Energy Pvt Ltd','GIDC Vatva, Ahmedabad','OEM',4.8),
('Precision Drivetrain Co','Faridabad, Haryana','OEM',3.9),
('OptiLight Systems','Bhiwandi, Maharashtra','Aftermarket',3.5);

INSERT INTO employee (emp_name, designation, salary, hire_date, plant_id) VALUES
('Ramesh Kumar','Supervisor',55000.00,'2015-06-12',1),
('Suresh Naik','Assembly Worker',28000.00,'2018-03-01',1),
('Anita Desai','Quality Inspector',42000.00,'2017-11-20',1),
('Vikram Singh','Assembly Worker',27500.00,'2019-07-15',2),
('Farah Khan','Manager',88000.00,'2013-01-09',2),
('Joseph Mathew','Mechanic',34000.00,'2016-09-05',3),
('Divya Rao','Quality Inspector',41000.00,'2020-02-17',4),
('Arjun Patel','Assembly Worker',27000.00,'2021-08-23',4),
('Meera Iyer','Service Advisor',36000.00,'2019-05-30',3),
('Karan Mehta','Sales Executive',32000.00,'2022-01-10',2);

INSERT INTO dealer (dealer_name, address, city, phone) VALUES
('SpeedWheels Motors','12 MG Road','Bengaluru','9880012345'),
('Metro TwoWheelers','45 Anna Salai','Chennai','9840012345'),
('Capital Rides','88 Karol Bagh','New Delhi','9811012345'),
('Deccan Bikes','7 MG Road','Hyderabad','9701012345'),
('Coastal Moto Hub','31 Jangli Maharaj Rd','Pune','9822012345');

INSERT INTO customer (customer_name, phone, email, address) VALUES
('Aditya Sharma','9008012345','aditya.s@gmail.com','22 Jayanagar, Bengaluru'),
('Priya Nair','9008023456','priya.nair@yahoo.com','14 Adyar, Chennai'),
('Rohan Gupta','9811023456','rohan.g@gmail.com','9 Pitampura, New Delhi'),
('Sneha Reddy','9701023456','sneha.r@gmail.com','3 Banjara Hills, Hyderabad'),
('Imran Ali','9822023456','imran.ali@gmail.com','18 Kothrud, Pune'),
('Kavya Menon','9845034567','kavya.m@gmail.com','5 Whitefield, Bengaluru');

-- ============================================================================
-- INSERT RECORDS (Part 2 : relationships / transactional data)
-- ============================================================================
INSERT INTO supplies (supplier_id, component_id, unit_price, lead_time_days, quality_rating) VALUES
(1,5,3600.00,10,4.6), (1,9,3100.00,12,4.4),               -- Bharat Brakes
(2,6,1950.00,7,4.3),  (2,7,2800.00,9,4.1),                -- Sunridges Tyres
(3,3,24500.00,21,4.9),(3,11,7900.00,18,4.7),              -- VoltCells
(4,1,21000.00,15,4.0), (4,2,26000.00,15,3.8), (4,10,4800.00,11,3.9), (4,13,18500.00,14,4.1), -- Precision Drivetrain
(5,8,1500.00,6,3.4),  (5,4,4300.00,14,3.6), (5,12,14800.00,20,3.7);  -- OptiLight

-- Each order stores the lead time agreed when it was placed. Later changes to
-- supplies.lead_time_days must not rewrite the performance of historical orders.
INSERT INTO supply_order (supplier_id, component_id, qty_ordered, unit_price, order_date, agreed_lead_time_days, delivery_date) VALUES
(1,5,5000,3600.00,'2026-05-02',10,'2026-05-11'),
(1,9,4000,3100.00,'2026-05-02',12,'2026-05-16'),
(2,6,8000,1950.00,'2026-04-18',7,'2026-04-24'),
(2,7,6000,2800.00,'2026-04-18',9,'2026-04-29'),   -- late delivery (11 days)
(3,3,3000,24500.00,'2026-06-01',21,'2026-06-19'),
(3,11,2500,7900.00,'2026-06-01',18,'2026-06-17'),
(4,1,4500,21000.00,'2026-05-20',15,'2026-06-04'),
(4,2,2000,26000.00,'2026-05-20',15,NULL),          -- not delivered yet
(4,13,900,18500.00,'2026-05-25',14,'2026-06-08'),  -- 110cc engines, on time (14 days)
(5,8,7000,1500.00,'2026-06-10',6,'2026-06-15'),
(5,4,3000,4300.00,'2026-06-10',14,'2026-06-27');   -- late delivery

INSERT INTO batch (batch_no, supplier_id, component_id, batch_qty, batch_date) VALUES
('ENG160-B001',4,1,1500,'2026-06-05'),
('ENG210-B001',4,2,800,'2026-06-05'),
('ENG110-B001',4,13,900,'2026-06-08'),
('BAT3K-A117', 3,3,1200,'2026-06-20'),
('BAT3K-A118', 3,3,1000,'2026-07-04'),
('ECU-B552',   5,4,2500,'2026-06-11'),
('BRK-D776',   1,5,4000,'2026-05-12'),
('TYR-90B221', 2,6,7500,'2026-04-25'),
('RIM-A774',   2,7,5500,'2026-04-30'),
('CTL-M900',   3,11,2000,'2026-06-18'),
('HUBM-3KW14', 5,12,1500,'2026-07-01'),
('LAMP-L331',  5,8,6000,'2026-06-15'),
('SUS-F410',   4,10,3000,'2026-06-01'),
('CLU-C441',   1,9,2000,'2026-05-18');

INSERT INTO model_component (model_code, component_id, qty_per_vehicle) VALUES
('XSP160',1,1),('XSP160',4,1),('XSP160',5,1),('XSP160',6,2),('XSP160',7,2),('XSP160',8,1),('XSP160',9,1),('XSP160',10,1),
('ZMR2100',2,1),('ZMR2100',4,1),('ZMR2100',5,1),('ZMR2100',6,2),('ZMR2100',7,2),('ZMR2100',8,1),('ZMR2100',9,1),('ZMR2100',10,1),
('SCT1100',13,1),('SCT1100',4,1),('SCT1100',5,1),('SCT1100',6,2),('SCT1100',7,2),('SCT1100',8,1),
('EVX3000',3,1),('EVX3000',11,1),('EVX3000',12,1),('EVX3000',5,1),('EVX3000',6,2),('EVX3000',7,2),('EVX3000',8,1),
('EVM5000',3,1),('EVM5000',11,1),('EVM5000',12,1),('EVM5000',5,1),('EVM5000',6,2),('EVM5000',7,2),('EVM5000',8,1),('EVM5000',10,1);

INSERT INTO vehicle (vin, model_code, plant_id, mfg_date, color, status, dealer_id, customer_id, sale_date, sale_price) VALUES
('MAT447000A1000001','XSP160',1,'2026-06-15','Racing Red','Sold',1,1,'2026-07-02',125000.00),
('MAT447000A1000002','XSP160',1,'2026-06-15','Matte Black','Sold',1,6,'2026-07-10',125000.00),
('MAT447000A1000003','XSP160',1,'2026-06-18','Racing Red','At-Dealer',1,NULL,NULL,NULL),
('MAT447000B2000001','ZMR2100',2,'2026-06-25','Pearl White','Sold',3,3,'2026-07-18',148500.00),
('MAT447000B2000002','ZMR2100',2,'2026-06-25','Pearl White','At-Dealer',3,NULL,NULL,NULL),
('MAT447000C3000001','SCT1100',3,'2026-07-01','Cyan Blue','Sold',5,5,'2026-07-20',87999.00),
('MAT447000C3000002','SCT1100',3,'2026-07-03','Cyan Blue','At-Dealer',5,NULL,NULL,NULL),
('MAT447000D4000001','EVX3000',4,'2026-07-10','Ice Silver','Sold',1,2,'2026-08-01',112000.00),
('MAT447000D4000002','EVX3000',4,'2026-07-12','Ice Silver','At-Dealer',2,NULL,NULL,NULL),
('MAT447000D4000003','EVX3000',4,'2026-07-12','Midnight Grey','At-Plant',NULL,NULL,NULL,NULL),
('MAT447000E5000001','EVM5000',4,'2026-07-15','Stealth Black','At-Dealer',4,NULL,NULL,NULL),
('MAT447000E5000002','EVM5000',4,'2026-07-16','Stealth Black','In-Production',NULL,NULL,NULL,NULL);

INSERT INTO vehicle_component (vin, component_id, batch_no, install_date, serial_no) VALUES
('MAT447000A1000001',6,'TYR-90B221','2026-06-15',NULL),
('MAT447000A1000001',6,'TYR-90B221','2026-06-15',NULL), -- second physical tyre
('MAT447000A1000001',1,'ENG160-B001','2026-06-15','ENG160-000781'),
('MAT447000A1000001',4,'ECU-B552','2026-06-15','ECU-000781'),
('MAT447000A1000001',5,'BRK-D776','2026-06-15',NULL),
('MAT447000A1000001',8,'LAMP-L331','2026-06-15',NULL),
('MAT447000A1000002',1,'ENG160-B001','2026-06-15','ENG160-000782'),
('MAT447000A1000002',4,'ECU-B552','2026-06-15','ECU-000782'),
('MAT447000A1000003',1,'ENG160-B001','2026-06-18','ENG160-000783'),
('MAT447000A1000003',4,'ECU-B552','2026-06-18','ECU-000783'),
('MAT447000B2000001',2,'ENG210-B001','2026-06-25','ENG210-000201'),
('MAT447000B2000001',4,'ECU-B552','2026-06-25','ECU-000201'),
('MAT447000B2000001',9,'CLU-C441','2026-06-25',NULL),
('MAT447000C3000001',13,'ENG110-B001','2026-07-01','ENG110-000904'),
('MAT447000D4000001',3,'BAT3K-A117','2026-07-10','BAT-117-000451'),
('MAT447000D4000001',11,'CTL-M900','2026-07-10','CTL-000451'),
('MAT447000D4000002',3,'BAT3K-A117','2026-07-12','BAT-117-000452'),
('MAT447000D4000003',3,'BAT3K-A118','2026-07-12','BAT-118-000501'),
('MAT447000E5000001',3,'BAT3K-A117','2026-07-15','BAT-117-000510'),
('MAT447000E5000001',12,'HUBM-3KW14','2026-07-15','HUB-000510'),
('MAT447000C3000002',5,'BRK-D776','2026-07-03',NULL);

INSERT INTO plant_inventory (plant_id, component_id, qty_on_hand, reorder_level) VALUES
(1,1,450,100),(1,4,800,150),(1,5,1200,200),(1,6,3000,500),(1,7,2600,400),(1,8,900,150),
(2,2,210,80),(2,4,600,120),(2,9,700,100),(2,10,450,90),
(3,13,320,100),(3,5,950,200),(3,6,2400,400),
(4,3,35,60),(4,11,220,50),(4,12,150,40),(4,5,400,100);

INSERT INTO dealer_inventory (dealer_id, component_id, qty_on_hand, reorder_level) VALUES
(1,5,60,20),(1,6,140,40),(1,8,80,25),(1,9,35,10),
(3,6,90,30),(3,7,75,25),
(4,3,2,5),(4,11,10,4),
(5,6,110,30),(5,8,70,20);

INSERT INTO service_record (vin, emp_id, service_date, service_type, odometer_km, cost, remarks) VALUES
('MAT447000A1000001',6,'2026-09-10','Free',1250,0.00,'First free service: oil change, chain tightening'),
('MAT447000A1000002',6,'2026-09-14','Paid',1800,1450.00,'Brake pad replacement'),
('MAT447000D4000001',9,'2026-09-05','Recall',640,0.00,'Battery pack inspection - batch BAT3K-A117'),
('MAT447000B2000001',6,'2026-09-20','Paid',2100,890.00,'General checkup, coolant top-up'),
('MAT447000C3000001',9,'2026-09-22','Free',950,0.00,'First free service');

INSERT INTO warranty (vin, warranty_type, start_date, end_date) VALUES
('MAT447000A1000001','Standard','2026-07-02','2029-07-02'),
('MAT447000A1000002','Standard','2026-07-10','2029-07-10'),
('MAT447000B2000001','Standard','2026-07-18','2029-07-18'),
('MAT447000B2000001','Extended','2026-07-18','2032-07-18'),
('MAT447000C3000001','Standard','2026-07-20','2029-07-20'),
('MAT447000D4000001','Standard','2026-08-01','2029-08-01'),
('MAT447000D4000001','Extended','2026-08-01','2031-08-01');

INSERT INTO warranty_claim (warranty_id, claim_date, defect_description, status, claim_amount, resolution) VALUES
(1,'2026-09-25','Headlamp flickering at low RPM','Resolved',1600.00,'Headlamp replaced free of cost'),
(3,'2026-09-18','Clutch slippage above 6000 RPM','Approved',3200.00,'Clutch assembly replacement scheduled'),
(6,'2026-09-08','Battery range dropped to 70 km per charge','Resolved',26000.00,'Battery pack BAT3K-A117 replaced under recall'),
(6,'2026-10-02','Controller error code E-11','Open',8200.00,NULL),
(5,'2026-09-30','Rear brake noise','Rejected',0.00,'Wear-and-tear item, not a manufacturing defect');

-- ============================================================================
-- SAMPLE QUERIES demonstrating the case-study problems are solved
-- ============================================================================
-- (a) Defect recall: one row per affected VIN, even if two parts share a batch
SELECT DISTINCT vc.vin
FROM vehicle_component vc
WHERE vc.batch_no = 'BAT3K-A117';

-- (b) Production (material) cost of each model from the Bill of Materials
SELECT mc.model_code,
       SUM(mc.qty_per_vehicle * c.unit_cost) AS material_cost
FROM model_component mc
JOIN component c ON c.component_id = mc.component_id
GROUP BY mc.model_code
ORDER BY material_cost DESC;

-- (c) Supplier performance: on-time delivery count per supplier
SELECT s.supplier_id, s.supplier_name,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN so.delivery_date IS NOT NULL
                 AND DATEDIFF(so.delivery_date, so.order_date) <= so.agreed_lead_time_days
                THEN 1 ELSE 0 END) AS on_time_orders
FROM supplier s
JOIN supply_order so ON so.supplier_id = s.supplier_id
GROUP BY s.supplier_id, s.supplier_name;

-- (d) Components below reorder level at any plant
SELECT p.plant_name, c.component_name, pi.qty_on_hand, pi.reorder_level
FROM plant_inventory pi
JOIN plant p ON p.plant_id = pi.plant_id
JOIN component c ON c.component_id = pi.component_id
WHERE pi.qty_on_hand < pi.reorder_level;

-- (e) Full service history of a vehicle with mechanic details
SELECT v.vin, m.model_name, sr.service_date, sr.service_type, sr.odometer_km, sr.cost, e.emp_name
FROM vehicle v
JOIN vehicle_model m ON m.model_code = v.model_code
JOIN service_record sr ON sr.vin = v.vin
LEFT JOIN employee e ON e.emp_id = sr.emp_id
WHERE v.vin = 'MAT447000A1000001'
ORDER BY sr.service_date;

-- (f) Sales report: vehicles sold with customer, dealer and price
SELECT c.customer_name, d.dealer_name, m.model_name, v.vin, v.sale_date, v.sale_price
FROM vehicle v
JOIN customer c ON c.customer_id = v.customer_id
JOIN dealer d   ON d.dealer_id   = v.dealer_id
JOIN vehicle_model m ON m.model_code = v.model_code
WHERE v.status = 'Sold'
ORDER BY v.sale_date;
