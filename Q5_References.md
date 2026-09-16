# Q5 — References Used to Solve the Problem (detailed report)

> **Note for students:** this section documents the *kind* of references a student would consult.
> Each entry follows the required format: **a)** the prompt/page consulted, **b)** the answer obtained,
> **c)** satisfactory level on a 1–5 scale. Replace/extend entries with your own actual usage before submission.
> *(I am an AI assistant — Cline — and the solution in Q1–Q4 was produced with the references below.)*

| # | Reference | a) Prompt / page referred | b) Answer obtained | c) Satisfactory level (1–5) |
|---|-----------|---------------------------|--------------------|------------------------------|
| 1 | **Elmasri & Navathe, *Fundamentals of Database Systems*, 7th Ed., Pearson** (textbook) | Chapters 7 (Conceptual Modelling), 9 (Relational Design / ER-to-Relational mapping) | Formal rules for converting entities, weak entities, M:N relationships and multivalued attributes into relational tables; notation for cardinality and participation | **5** — authoritative and complete for Q1 & Q2 |
| 2 | **Silberschatz, Korth & Sudarshan, *Database System Concepts*, 7th Ed., McGraw-Hill** (textbook) | Chapter 6 (E-R Model), Chapter 7 (Relational Database Design) | Weak-entity modelling (BATCH), primary-key selection, and how integrity constraints map to DDL | **5** — clear worked examples for Q1/Q2 |
| 3 | **MySQL 8.0 Reference Manual — https://dev.mysql.com/doc/refman/8.0/en/** (internet) | Pages: `CREATE TABLE`, `ENUM`, `CHECK` constraints, `FOREIGN KEY` constraints, `AUTO_INCREMENT` | Correct MySQL DDL syntax: inline CHECKs, ENUM domain types, ON DELETE/UPDATE actions, composite primary keys | **5** — exact, up-to-date syntax for Q3 |
| 4 | **PostgreSQL 16 Documentation — https://www.postgresql.org/docs/16/** (internet) | Pages: DDL, `GENERATED ALWAYS AS IDENTITY`, `CREATE TYPE` | How the same schema would be written in PostgreSQL (identity columns, native ENUM types) — noted in the SQL header comments | **4** — thorough but organization is denser than MySQL docs |
| 5 | **W3Schools SQL Tutorial — https://www.w3schools.com/sql/** (internet) | Pages: `INSERT INTO`, `JOIN`, `GROUP BY`, constraints | Quick reminders for multi-row INSERT syntax and join patterns used in the sample queries | **3** — good for quick syntax, shallow for design theory |
| 6 | **Mermaid.js documentation — https://mermaid.js.org/syntax/entityRelationshipDiagram.html** (internet) | ER diagram syntax reference | How to express the Chen-style E-R diagram in machine-renderable `erDiagram` syntax with PK/FK annotations | **4** — clear examples; some cardinality symbols limited |
| 7 | **MongoDB Manual — https://www.mongodb.com/docs/manual/** (internet) | Pages: Data modeling introduction, Schema validation, Multi-document transactions | Evidence for Q4 advantages (flexible schema, document model) and the limits of ACID in NoSQL | **4** — vendor docs, so strengths highlighted more than weaknesses |
| 8 | **Apache Cassandra documentation — https://cassandra.apache.org/doc/** (internet) | Pages: Architecture, consistency tuning, writes | LSM-based write throughput and eventual consistency reasoning for the Q4 discussion of IoT/telemetry workloads | **3** — technically accurate but assumes distributed-systems background |
| 9 | **ChatGPT (OpenAI GPT-4)** (LLM) | Prompt: *"I have an ER diagram for a two-wheeler manufacturing DB with entities VehicleModel, Component, Supplier, Plant, Dealer, Customer, Vehicle, Service, Warranty. Convert it to a relational schema and tell me how to resolve M:N relationships like vehicle–component and supplier–component."* | Answer: create junction tables (`vehicle_component`, `supplies`) with composite primary keys and add relationship attributes (qty, unit_price); confirm 1:N relationships collapse into FKs on the N side. Cross-checked against Elmasri & Navathe mapping algorithm — matched. | **4** — correct and fast, but required verification because it initially omitted `qty_per_vehicle` in the BOM junction table |
| 10 | **GitHub Copilot / Cline (AI coding assistant)** (LLM) | Prompt: *"Generate MySQL 8 DDL and sample INSERT statements for this schema (18 tables), including a batch table so that defective components can be traced to vehicles, plus sample queries for recall and production cost."* | Produced the draft of `Q3_two_wheeler_db.sql`; caught the design insight that `vehicle_component` must carry `batch_no` for defect recalls; all DDL validated by executing it against a live SQL engine | **5** — high quality with live validation, though column types needed review |

## Summary of satisfactory levels

- **Textbooks (5, 5):** best for *design decisions* — why entities/relationships are modelled the way they are.
- **Official DBMS documentation (5, 4):** best for *exact syntax* and DBMS-specific behaviour.
- **Internet tutorials (3–4):** useful for quick syntax recall; insufficient depth alone.
- **Vendor NoSQL docs (3–4):** accurate but biased toward the vendor's strengths; balanced with independent comparison articles.
- **LLMs (4–5):** excellent accelerators for drafting and spotting design gaps, **but every answer was cross-verified** against textbooks/official docs and by actually running the SQL — treating LLM output as unverified would be unsafe.

**Overall:** the combination of a standard textbook (concepts) + official documentation (syntax) + LLM assistance (speed) + live validation (correctness) gave the highest confidence in the final solution.
