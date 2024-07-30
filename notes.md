# Notes

> notes taken during the course

## Section 1: Working with database [Postgres + SQLC]

#### Docker Postgres

```sh
docker pull postgres:12-alpine
docker images
docker run --name postgres12 -e POSTGRES_USER=root -e POSTGRES_PASSWORD=secret -d -p 5432:5432 postgres:12-alpine
docker ps
docker exec -it postgres12 psql -U root
```

```sql
select now();
\q
```

```sh
docker logs postgres12
docker stop postgres12
docker ps -a
docker start postgres12
```

#### Migrate

```sh
$ brew install golang-migrate
$ migrate -version
mkdir -p db/migration
migrate create -ext sql -dir db/migration -seq init_schema
```

```sh
docker exec -it postgres12 /bin/sh
```

```sh
createdb --username=root --owner=root simple_bank
psql simple_bank
\q
```

```sql
dropdb simple_bank
exit
```

```sh
docker exec -it postgres12 createdb --username=root --owner=root simple_bank
docker exec -it postgres12 psql -U root simple_bank
\q
```

```sh
docker rm postgres12
```

```sh
make postgres
docker ps
make createdb
```

```sh
migrate -path db/migration -database "postgresql://root:secret@localhost:5432/simple_bank?sslmode=disable" -verbose up
migrate -path db/migration -database "postgresql://root:secret@localhost:5432/simple_bank?sslmode=disable" -verbose down
```

#### CRUD

Database/SQL
- Very fast & straightforward
- Manual mapping SQL fields to variables
- Easy to make mistakes, not caught until runtime

GORM
- CRUD functions already implemented, veru short production code
- Must learn to write queries using gorm's function
- Run slowly on high load

SQLX
- Quite Fast & easy to use
- Fields mapping via query text & struct tags
- Failure won't be occur until runtime

SQLC
- Very Fast & easy to use
- Automatic code generation
- Catch SQL query errors before generating codes
- Full support for PostgreSQL, MySQL, SQLite


#### SQLC

```sh
brew install sqlc
sqlc version
sqlc init
```
https://docs.sqlc.dev/en/stable/reference/config.html

After editing `sqlc.yaml` and `query.sql` files, run:

```sh
sqlc generate
# OR
make sqlc
```

```sh
go mod init github.com/filipe1309/ud-bmc-simplebank
go mod tidy
```

### Write unit tests for database CRUD with random data in Golang

https://github.com/lib/pq

```sh
go get github.com/lib/pq
go get github.com/stretchr/testify
```


### A clean way to implement database transaction in Golang

Transaction
- A sequence of operations performed as a single logical unit of work
- Provide a reliable and consistent unit of work, even in a case of system failure
- Provide isolation between programs accessing the database concurrently
- ACID properties: Atomicity, Consistency, Isolation, Durability


#### Deadlock

Example with 2 transacions each in a goroutine, on deadlock:

```sh
>> before: 224 23
tx 2 create transfer # -----> Lock accounts too
# tx 2: INSERT INTO transfers (from_account_id, to_account_id, amount) VALUES (1, 2, 10) RETURNING *;
tx 2 create entry 1
# tx 2: INSERT INTO entries (account_id, amount) VALUES (1, -10) RETURNING *;
tx 1 create transfer # -----> Lock accounts too
# tx 1: INSERT INTO transfers (from_account_id, to_account_id, amount) VALUES (1, 2, 10) RETURNING *;
tx 2 create entry 2
# tx 2: INSERT INTO entries (account_id, amount) VALUES (2, 10) RETURNING *;
tx 2 get account 1 # -----> Wait accounts to be unlocked...
# tx 2: SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
tx 1 create entry 1
# tx 1: INSERT INTO entries (account_id, amount) VALUES (1, -10) RETURNING *;
tx 1 create entry 2
# tx 2: INSERT INTO entries (account_id, amount) VALUES (2, 10) RETURNING *;
tx 1 get account 1 # -----> Wait accounts to be unlocked... -----> DEADLOCK!!!!!!
# tx 1: SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
tx update get account 1
# tx 1: UPDATE accounts SET balance = 110 WHERE id = 2 RETURNING *;
deadlock!!!
```

```sql
BEGIN;

INSERT INTO transfers (from_account_id, to_account_id, amount) VALUES (1, 2, 10) RETURNING *; -- deadlock trigger

INSERT INTO entries (account_id, amount) VALUES (1, -10) RETURNING *;
INSERT INTO entries (account_id, amount) VALUES (2, 10) RETURNING *;

SELECT * FROM accounts WHERE id = 1 FOR UPDATE; -- deadlock here on tx 2!!!!
UPDATE accounts SET balance = 90 WHERE id = 1 RETURNING *;

SELECT * FROM accounts WHERE id = 2 FOR UPDATE;
UPDATE accounts SET balance = 110 WHERE id = 2 RETURNING *;

ROLLBACK;
```

`SELECT * FROM accounts WHERE id = 1 FOR UPDATE;` of `tx 2` is blocked by `INSERT INTO transfers (from_account_id, to_account_id, amount) VALUES (1, 2, 10) RETURNING *;` of `tx 1`

Why?

Because of `ALTER TABLE "transfers" ADD FOREIGN KEY ("from_account_id") REFERENCES "accounts" ("id");` has a reference from `transfers` to `accounts` with the `FOREIGN KEY` clause. So when `tranfers` is locked with a transaction (`tx 1`)
the `accounts` table will also be locked, causing deadlock when some other transaction try to access its content(`tx 2`), because of this reference `FOREIGN KEY`, and to keep its consistency.  
To Avoid that deadlock, we must inform psql that the primary key wont be updated on `SELECT * FROM accounts WHERE id = 1 FOR UPDATE;` query.  
In order to do that we can add `NO KEY` on the query, like: `SELECT * FROM accounts WHERE id = 1 FOR NO KEY UPDATE;`.

Postgres Lock Monitoring:

```sql
SELECT blocked_locks.pid     AS blocked_pid,
      blocked_activity.usename  AS blocked_user,
      blocking_locks.pid     AS blocking_pid,
      blocking_activity.usename AS blocking_user,
      blocked_activity.query    AS blocked_statement,
      blocking_activity.query   AS current_statement_in_blocking_process
FROM  pg_catalog.pg_locks         blocked_locks
  JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
  JOIN pg_catalog.pg_locks         blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid

  JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

```sql
SELECT a.datname,
         a.application_name,
         l.relation::regclass,
         l.transactionid,
         l.mode,
         l.locktype,
         l.GRANTED,
         a.usename,
         a.query,
         a.query_start,
         age(now(), a.query_start) AS "age",
         a.pid
FROM pg_stat_activity a
JOIN pg_locks l ON l.pid = a.pid
WHERE a.application_name = 'psql'
ORDER BY a.pid;
```
