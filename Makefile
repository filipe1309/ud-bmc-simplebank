.PHONY: test run help createdb dropdb postgres migrateup migratedown sqlc install server mock rundb migrateup1 migratedown1

DB_URL=postgresql://root:secret@localhost:5432/simple_bank?sslmode=disable

install: createdb migrateup

postgres:
	docker run --name postgres12 -e POSTGRES_USER=root -e POSTGRES_PASSWORD=secret -d -p 5432:5432 postgres:12-alpine

createdb:
	docker exec -it postgres12 createdb --username=root --owner=root simple_bank

dropdb:
	docker exec -it postgres12 dropdb simple_bank

migrateup:
	migrate -path db/migration -database "$(DB_URL)" -verbose up

migrateup1:
	migrate -path db/migration -database "$(DB_URL)" -verbose up 1

migratedown:
	migrate -path db/migration -database "$(DB_URL)" -verbose down

migratedown1:
	migrate -path db/migration -database "$(DB_URL)" -verbose down 1

sqlc:
	sqlc generate

# run tests
test:
	@echo "🟢 Running tests..."
	go test -v -cover ./...

# run node
run: server
	@echo "🏁 Running code..."

rundb:
	docker exec -it postgres12 psql -U root -d simple_bank

server:
	go run main.go

mock:
	mockgen -package mockdb -destination db/mock/store.go github.com/filipe1309/ud-bmc-simplebank/db/sqlc Store

help:
	@echo "📖 Available commands:"
	@echo "  make install"
	@echo "  make postgres"
	@echo "  make createdb"
	@echo "  make dropdb"
	@echo "  make migrateup"
	@echo "  make migrateup1"
	@echo "  make migratedown"
	@echo "  make migratedown1"
	@echo "  make sqlc"
	@echo "  make run"
	@echo "  make rundb"
	@echo "  make server"
	@echo "  make test"
	@echo "  make help"
