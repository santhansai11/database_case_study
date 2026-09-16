# Q4 — NoSQL vs RDBMS for the Two-Wheeler Manufacturing System (10 points)

If this integrated database were built on **NoSQL** (e.g. MongoDB document store, Cassandra wide-column, Neo4j graph) instead of **MySQL/PostgreSQL RDBMS**, the following advantages and disadvantages arise:

## Advantages of NoSQL in this scenario

1. **Flexible / evolving schema** — Vehicle models change fast (new EV variants, new attributes like battery chemistry or OTA-software version). Document stores (MongoDB) let each model document have different fields without `ALTER TABLE` migrations or NULL-heavy tables.
2. **Horizontal scalability** — Telemetry/fitment data (every component fitted in every vehicle, sensor logs) grows to billions of rows. Sharding across commodity servers is built into MongoDB/Cassandra; RDBMS scale-up (bigger server) is costlier.
3. **High write throughput for manufacturing/IoT data** — Assembly-line events (a vehicle passes a station every few seconds across plants) generate massive insert streams; Cassandra's LSM storage and log-structured writes handle this better than a row-store RDBMS with ACID overhead.
4. **Natural fit for hierarchical product data** — A vehicle model with its Bill of Materials and specs is naturally one JSON document; NoSQL avoids the multiple joins between `vehicle_model`, `model_component`, `component` when displaying a product page.
5. **Availability & partition tolerance** — Multi-plant, multi-dealer geographically distributed system; NoSQL's eventual consistency / tunable consistency (Cassandra, DynamoDB-style) keeps dealers able to check stock even during network partitions (BASE instead of strict ACID).
6. **Better handling of semi-structured and unstructured data** — Warranty claim photos, PDF invoices, technician voice notes, sensor JSON blobs can be stored in the same record; RDBMS needs BLOB columns or a separate file store.
7. **Aggregation-first analytics** — MongoDB's aggregation pipeline or Cassandra materialized views pre-compute supplier on-time %, inventory dashboards quickly without complex multi-join SQL.
8. **Graph option for recall tracing** — Neo4j can traverse VIN → fitted component → batch → supplier in milliseconds across millions of vehicles, ideal for "identify vehicles affected by defective components" and for supplier-network analysis.

## Disadvantages of NoSQL in this scenario

9. **Loss of strong ACID guarantees across entities** — A sale must simultaneously update `vehicle.status`, insert a sale record, and decrement dealer stock. RDBMS guarantees all-or-nothing; in NoSQL (other than single-document transactions) partial updates can leave inconsistent state — unacceptable for financial/sales data.
10. **No enforced referential integrity / duplicate risk returns** — NoSQL has no foreign keys, so duplicate customer records (the very problem in the case study) reappear because the database will not reject an orphan or a duplicate; deduplication must be handled entirely in application code, which is error-prone.
11. **Complex joins and ad-hoc queries become painful** — Questions like "service history of vehicles sold by dealers in city X with claims on components from supplier Y" require multi-level joins; in SQL this is one query, in NoSQL it becomes many round-trips or manual application-side joins.
12. **Schema-less data invites inconsistency** — Nothing stops one plant's records using `mfg_date` and another's `manufactureDate`, or storing price as a string; data-quality enforcement, CHECK constraints and validations must be reimplemented in every application.
13. **Mature tooling, reporting and BI support is weaker** — The RDBMS ecosystem (standard SQL, stored procedures, mature backup/recovery, role-based security, ERP/BI connectors) is far richer; teams trained on SQL face a steeper learning curve with proprietary query languages (MQL, CQL, Cypher).
14. **Eventual consistency complicates critical operations** — A dealer may sell a vehicle that another dealer's screen still shows as available (stale replica), or a claim may be approved against an outdated warranty record because updates had not propagated.

## Balanced conclusion

The best practical architecture is often **polyglot persistence**: keep the transactional core (models, components, suppliers, sales, warranty, inventory) in an **RDBMS** for ACID and integrity, and offload high-volume/semi-structured data (assembly-line telemetry, claim documents, IoT sensor streams) to NoSQL stores.
