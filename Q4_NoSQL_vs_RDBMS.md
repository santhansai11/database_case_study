# Q4 — NoSQL vs RDBMS for the Two-Wheeler Manufacturing System

NoSQL includes different database families. The following ten points compare specific capabilities with MySQL/PostgreSQL; they are not universal properties of every NoSQL database.

## Potential advantages

1. **Flexible product attributes.** A MongoDB document can store battery chemistry on an electric model and engine capacity on a petrol model. This suits varying specifications. Relational systems can also use subtype tables or JSON columns, so flexibility is not exclusive to NoSQL.
2. **Distributed workloads.** Cassandra distributes data across nodes, which can suit vehicle telemetry from many plants. Partition keys and access patterns must be designed carefully. Relational systems can also scale through partitioning, replication and distributed implementations; NoSQL is not automatically cheaper or faster.
3. **Availability choices.** Cassandra offers tunable consistency for reads and writes. Less critical sensor readings can favour availability, while stock decisions need stronger coordination. This is a workload-specific tradeoff, not a reason to weaken every transaction. [Cassandra architecture](https://cassandra.apache.org/doc/latest/cassandra/architecture/dynamo.html)
4. **Related data in one document.** A model and its BOM can be embedded together for a single read. Updating one document is atomic in MongoDB. Duplicating component descriptions across models, however, creates extra update work. [MongoDB transactions](https://www.mongodb.com/docs/manual/core/transactions/)
5. **Variable service and claim details.** Documents can hold different inspection results, diagnostic fields and attachment metadata without many optional columns. Large photos and invoices can remain in file/object storage with references; embedding arbitrary files is not an inherent NoSQL advantage.

## Limitations and design tradeoffs

6. **Transactions depend on the product and deployment.** MongoDB supports multi-document ACID transactions on replica sets and sharded clusters, with overhead compared with single-document writes. A sale that changes several documents still needs an explicit transaction, just as several SQL updates do. It is incorrect to say NoSQL cannot provide ACID. [MongoDB transactions](https://www.mongodb.com/docs/manual/core/transactions/)
7. **Uniqueness and referential integrity are different.** MongoDB unique indexes can reject duplicate VINs or phone numbers, subject to sharding/index restrictions. Cross-collection references do not have SQL-style foreign-key enforcement, so ensuring every referenced model exists requires additional application/database design. [Unique indexes](https://www.mongodb.com/docs/manual/core/index-unique/)
8. **Reports depend on the data model.** MongoDB's `$lookup` performs joins inside an aggregation pipeline, and graph databases are designed around relationships. Complex supplier–vehicle–service reports may nevertheless need careful indexing or denormalization; they do not necessarily require application-side joins. [MongoDB $lookup](https://www.mongodb.com/docs/manual/reference/operator/aggregation/lookup/)
9. **Schema validation is available but must be configured.** MongoDB validators can require fields and constrain types and values, preventing inconsistent date names or textual prices. A flexible collection without suitable validation can drift; that is not the same as having no enforcement capability. [Schema validation](https://www.mongodb.com/docs/manual/core/schema-validation/)
10. **Consistency must match each operation.** Cassandra's consistency level and replication design affect what reads observe. Stale stock is a risk under weak consistency choices, not an unavoidable property of NoSQL. Relational read replicas may also lag. Selling a specific vehicle requires an atomic availability check/update, with suitable consistency and transaction settings. [Cassandra architecture](https://cassandra.apache.org/doc/latest/cassandra/architecture/dynamo.html)

## Recommendation for this case

Use an RDBMS for the integrated core because its foreign keys, constraints, joins and transactions fit the highly related manufacturing, sales and service records. Consider a document or distributed store for variable diagnostics or high-volume telemetry when workload evidence justifies it. The choice depends on required guarantees and measured workload, not a blanket SQL/NoSQL ranking.
