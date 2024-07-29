.PHONY: test run help createdb dropdb postgres migrateup migratedown sqlc install

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

migratedown:
	migrate -path db/migration -database "$(DB_URL)" -verbose down

sqlc:
	sqlc generate

# run tests
test:
	@echo "🟢 Running tests..."
	go test -v -cover ./...

# run node
run:
	@echo "🏁 Running code..."

help:
	@echo "📖 Available commands:"
	@echo "  make install"
	@echo "  make postgres"
	@echo "  make createdb"
	@echo "  make dropdb"
	@echo "  make migrateup"
	@echo "  make migratedown"
	@echo "  make sqlc"
	@echo "  make run"
	@echo "  make test"
	@echo "  make help"
