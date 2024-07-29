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


