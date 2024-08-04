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


### How to avoid deadlock in DB transaction? Queries order matters!

Deadlock transactions:

```sql
-- Tx1: transfers $10 from account 1 to account 2
BEGIN; -- #1

UPDATE accounts SET balance = balance - 10 WHERE id = 1 RETURNING *; -- #2 blocks accounts...
UPDATE accounts SET balance = balance + 10 WHERE id = 2 RETURNING *; -- #5 -- Query is blocked!!, because Tx2 is updating account with id = 2

ROLLBACK;

-- Tx2: transfers $10 from account 2 to account 1
BEGIN; -- #3

UPDATE accounts SET balance = balance - 10 WHERE id = 2 RETURNING *; -- #4 blocks accounts...
UPDATE accounts SET balance = balance + 10 WHERE id = 1 RETURNING *; -- #6 DEADLOCK!!!

ROLLBACK;
```


Solution, update the accounts in the same order:

```sql
-- Tx1: transfers $10 from account 1 to account 2
BEGIN; -- #1

UPDATE accounts SET balance = balance - 10 WHERE id = 1 RETURNING *; -- #2 blocks accounts id = 1...
UPDATE accounts SET balance = balance + 10 WHERE id = 2 RETURNING *; -- #5

COMMIT; -- #6

-- Tx2: transfers $10 from account 2 to account 1
BEGIN; -- #3

UPDATE accounts SET balance = balance + 10 WHERE id = 1 RETURNING *; -- #4 Query is blocked!!, because Tx1 is updating account with id = 1, Unblocks after Tx1 COMMIT
UPDATE accounts SET balance = balance - 10 WHERE id = 2 RETURNING *; -- #7

COMMIT; -- #8 No deadlock =)
```

Refactor of account balance update

v1:

```go
fmt.Println(txName, "create account 1")
account1, err := q.GetAccountForUpdate(ctx, arg.FromAccountID)
if err != nil {
	return err
}

fmt.Println(txName, "update account 1")
result.FromAccount, err = q.UpdateAccount(ctx, UpdateAccountParams{
	ID:      arg.FromAccountID,
	Balance: account1.Balance - arg.Amount,
})
if err != nil {
	return err
}
```

v2:

```go
result.FromAccount, err = q.AddAccountBalance(ctx, AddAccountBalanceParams{
	ID:     arg.FromAccountID,
	Amount: -arg.Amount,
})
if err != nil {
	return err
}
```

v3:

```go
result.FromAccount, result.ToAccount, err = addMoney(ctx, q, arg.FromAccountID, -arg.Amount, arg.ToAccountID, arg.Amount)
```


### Deeply understand the database transaction isolation levels & read phenomena

ACID Properties: Atomicity, Consistency, Isolation, Durability

Read Phenomena: Is a situation where one transaction reads data that is being modified by another transaction, and the final result of the first transaction is different from the result of the second transaction.
- Dirty Read: A transaction reads uncommitted data from another transaction
- Non-Repeatable Read: A transaction reads different data in two separate reads
- Phantom Read: A transaction reads different rows in two separate reads
- Serialization Anomaly: A transaction reads data that is inconsistent with the database state


4 Standard of Isolation Levels (from lowest to highest):
- Read Uncommitted: Can see data written by uncommitted transactions
- Read Committed: Can only see data written by committed transactions
- Repeatable Read: Same read query always returns the same result
- Serializable: Can achieve the same result as if transactions were executed serially instead of concurrently

Isolation levels in MySQL:

```sql
SELECT @@GLOBAL.tx_isolation, @@tx_isolation;
SET tx_isolation = 'READ-UNCOMMITTED'; -- Read Uncommitted on current session
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; -- Read Uncommitted on current session
SET GLOBAL tx_isolation = 'READ-UNCOMMITTED'; -- Read Uncommitted on global session
```

Isoaltion levels in Postgres:

```sql
SHOW default_transaction_isolation;
SHOW TRANSACTION ISOLATION LEVEL;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; -- Read Uncommitted on current session, in Postgres is not supported, will be set to READ COMMITTED
```

Table Isoaltion Levels x Read Phenomena in MySQL:

|        MySQL         | Read Uncommitted | Read Committed | Repeatable Read | Serializable |
|----------------------|------------------|----------------|-----------------|--------------|
| Dirty Read           | Yes              | No             | No              | No           |
| Non-Repeatable Read  | Yes              | Yes            | No              | No           |
| Phantom Read         | Yes              | Yes            | No              | No           |
| Serialization Anomaly| Yes              | Yes            | Yes             | No           |

- 4 levels of isolation: Read Uncommitted, Read Committed, Repeatable Read, Serializable
- Use locking mechanism to prevent dirty read, non-repeatable read, phantom read, and serialization anomaly
- Default isolation level: Repeatable Read

Table Isoaltion Levels x Read Phenomena in Postgres:

|      PostgreSQL      | Read Uncommitted | Read Committed | Repeatable Read | Serializable |
|----------------------|------------------|----------------|-----------------|--------------|
| Dirty Read           | No               | No             | No              | No           |
| Non-Repeatable Read  | Yes              | Yes            | No              | No           |
| Phantom Read         | Yes              | Yes            | No              | No           |
| Serialization Anomaly| Yes              | Yes            | Yes             | No           |

- 3 levels of isolation: Read Committed, Repeatable Read, Serializable
- There is no Read Uncommitted in Postgres
- Use dependencies detection mechanism to prevent dirty read, non-repeatable read, phantom read, and serialization anomaly
- Default isolation level: Read Committed

### 12. Setup Github Actions for Golang + Postgres to run automated tests

```sh
mkdir -p .github/workflows
touch .github/workflows/ci.yml
```

## Section 2: Building RESTful HTTP JSON API [Gin + JWT + PASETO]

### Implement Restful HTTP JSON API in Go using Gin

```sh
go get -u github.com/gin-gonic/gin
```

### Load config file from & environment variables in Go with Viper

```sh
go get github.com/spf13/viper
```

```sh
SERVER_ADDRESS=0.0.0.0:8081 make server
```

### Mock DB for testing HTTP API in Go and achieve 100% coverage

```sh
go install go.uber.org/mock/mockgen@latest
go get go.uber.org/mock/mockgen/model
mockgen -package mockdb -destination db/mock/store.go github.com/filipe1309/ud-bmc-simplebank/db/sqlc Store
```

Test API with mock DB:

v1:

```go
func TestGetAccountAPI(t *testing.T) {
	account := randomAccount()

	testCases := []struct {
		name         string
		accountID    int64
		buildStubs func(store *mockdb.MockStore)
		checkResponse func(t *testing.T, recorder *httptest.ResponseRecorder)
	}{
		{
			name: "OK",
			accountID: account.ID,
			buildStubs: func(store *mockdb.MockStore) {
				
			}
		}
	}

	ctrl := gomock.NewController(t)
	defer ctrl.Finish()

	store := mockdb.NewMockStore(ctrl)
	// build stubs
	store.EXPECT().
		GetAccount(gomock.Any(), gomock.Eq(account.ID)).
		Times(1).
		Return(account, nil)

	// start test server and send request
	server := NewServer(store)
	recorder := httptest.NewRecorder()

	url := fmt.Sprintf("/accounts/%d", account.ID)
	request, err := http.NewRequest(http.MethodGet, url, nil)
	require.NoError(t, err)

	server.router.ServeHTTP(recorder, request)

	// check response
	require.Equal(t, http.StatusOK, recorder.Code)
	requireBodyMatchAccount(t, recorder.Body, account)
}
```

### 17. Add users table with unique & foreign key constraints in PostgreSQL

```sh
migrate create -ext sql -dir db/migration -seq add_users
```

### 21. Why PASETO is better than JWT for token-based authentication?

Token-based Authentication:

```
Client                                               Server
	| 1. POST /users/login                               |
	| -------------------------------------------------> |
	| {username: "user1", password: "password1"}         |
	|                                                    |
	|                                   Signed JWT Token |
	| <------------------------------------------------- |
	|                   200 OK {access_token: "xxxxx"}   | JWT, PASETO,...
	|                                                    |
	| 2. GET /accounts                                   |
	| -------------------------------------------------> |
	| Authorization: Bearer xxxxx                        |
	|                                                    |
	|                                  Verify JWT Token  |
	| <------------------------------------------------- |
	|                        200 OK [account1, account2] |
```

JWT: JSON Web Token  
PASETO: Platform-Agnostic Security Tokens  

## Section 3: Deploying the application to production [Docker + Kubernetes + AWS]

### 25. How to build a small Golang Docker image with a multistage Dockerfile

Simple Dockerfile:
- One stage: 586MB

```dockerfile
FROM golang:1.22.5-alpine3.20
WORKDIR /app
COPY . .
RUN go build -o main main.go

EXPOSE 8080
CMD ["/app/main"]
```

To remove a container or an image:
```sh
docker rm <container_id>
docker rmi <image_id>
```

Multistage Dockerfile:
- Two stages: 22.3MB

```dockerfile
# Build stage
FROM golang:1.22.5-alpine3.20 AS builder
WORKDIR /app
COPY . .
RUN go build -o main main.go

# Run stage
FROM alpine:3.20
WORKDIR /app
COPY --from=builder /app/main .

EXPOSE 8080
CMD ["/app/main"]
```

After creating the Dockerfile:

```sh
docker build -t simplebank:latest . # build the image
docker images # list images
```

```sh
docker run --name simplebank -p 8080:8080 simplebank:latest # run the container
docker ps # list containers
```

```sh
docker exec -it <container_id> /bin/sh # enter the container
exit
```

```sh
curl -X POST http://localhost:8080/users/login -d '{"username": "user1", "password": "password1"}' -H "Content-Type: application/json"
```

```sh
docker stop <container_id> # stop the container
```

```sh
docker ps -a # list all containers
```

```sh
docker rm simplebank
```

Run the container with environment variables and release mode:
```sh
docker run --name simplebank -p 8080:8080 -e GIN_MODE=release simplebank:latest
```

simplebank container could not connect to postgres12 container, because they have different IP addresses:

```sh
docker container inspect postgres12 # NetworkSettings.IPAddress 172.17.0.2
docker container inspect simplebank # NetworkSettings.IPAddress 172.17.0.3
```

So, we can set the IP address of the postgres12 container as an environment variable in the simplebank container:

```sh
docker run --name simplebank -e GIN_MODE=release -e DB_SOURCE="postgresql://root:secret@172.17.0.2:5432/simple_bank?sslmode=disable" -p 8080:8080 simplebank:latest
```

But, this is not a good practice, because the IP address of the postgres12 container could change.

To solve this problem, we can use the name of the container as the hostname, but not with the default bridge network, because it does not support container name resolution.

```sh
docker network ls
docker network inspect bridge
```

So, we can create a new network:

```sh
docker network create simplebank-network
docker network ls
docker network connect simplebank-network postgres12
docker network inspect simplebank-network
docker container inspect postgres12
```

```sh
docker run --name simplebank -e GIN_MODE=release -e DB_SOURCE="postgresql://root:secret@postgres12:5432/simple_bank?sslmode=disable" -p 8080:8080 --network simplebank-network simplebank:latest
```

```sh
docker network inspect simplebank-network
```

### 27. How to write docker-compose file and control service start-up orders

```sh
touch docker-compose.yml
```

```sh
docker-compose up
```

```sh
chmod +x start.sh
```
