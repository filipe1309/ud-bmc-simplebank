# Notes

> notes taken during the course

## Section 1: Working with database [Postgres + SQLC]

### Docker Postgres

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

### Migrate

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
