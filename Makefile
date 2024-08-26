.PHONY: test run help createdb dropdb postgres migrateup migratedown sqlc install server mock rundb migrateup1 migratedown1 up db_docs db_schema proto evans redis upredis new_migration

DB_URL=postgresql://root:secret@localhost:5432/simple_bank?sslmode=disable

install: createdb migrateup

postgres:
	docker run --name postgres12 --network simplebank-network -e POSTGRES_USER=root -e POSTGRES_PASSWORD=secret -d -p 5432:5432 postgres:12-alpine

createdb:
	docker exec -it postgres12 createdb --username=root --owner=root simple_bank

dropdb:
	docker exec -it postgres12 dropdb simple_bank

# example: make new_migration name=create_users_table
new_migration:
	migrate create -ext sql -dir db/migration -seq $(name)

migrateup:
	migrate -path db/migration -database "$(DB_URL)" -verbose up

migrateup1:
	migrate -path db/migration -database "$(DB_URL)" -verbose up 1

migratedown:
	migrate -path db/migration -database "$(DB_URL)" -verbose down

migratedown1:
	migrate -path db/migration -database "$(DB_URL)" -verbose down 1

db_docs:
	dbdocs build doc/db.dbml

db_schema:
	dbml2sql --postgres -o db/schema.sql doc/db.dbml

sqlc:
	sqlc generate

test:
	@echo "🟢 Running tests..."
	go test -v -cover -short ./...

run: 
	@echo "🚀 Running server & db containers..."
	docker compose up --force-recreate

stop:
	@echo "🛑 Stopping server & db containers..."
	docker compose down

rundb:
	docker exec -it postgres12 psql -U root -d simple_bank

updb:
	docker compose up postgres -d

server: updb upredis
	go run main.go

mock:
	mockgen -package mockdb -destination db/mock/store.go github.com/filipe1309/ud-bmc-simplebank/db/sqlc Store

proto:
	rm -f pb/*.go
	rm -f doc/swagger/*.swagger.json
	protoc --proto_path=proto --go_out=pb --go_opt=paths=source_relative \
    --go-grpc_out=pb --go-grpc_opt=paths=source_relative \
		--grpc-gateway_out=pb --grpc-gateway_opt paths=source_relative \
		--openapiv2_out=doc/swagger --openapiv2_opt=allow_merge=true,merge_file_name=simple_bank \
    proto/*.proto
		statik -src=./doc/swagger -dest=./doc

evans:
	evans --host localhost --port 9090 --package pb --service SimpleBank -r repl

redis:
	docker run --name redis -d -p 6379:6379 redis:7-alpine

upredis:
	docker compose up redis -d

help:
	@echo "📖 Available commands:"
	@echo "  make install"
	@echo "  make postgres"
	@echo "  make createdb"
	@echo "  make dropdb"
	@echo "  make new_migration name=<migration-name>"
	@echo "  make migrateup"
	@echo "  make migrateup1"
	@echo "  make migratedown"
	@echo "  make migratedown1"
	@echo "  make sqlc"
	@echo "  make test"
	@echo "  make run"
	@echo "  make stop"
	@echo "  make rundb"
	@echo "  make server"
	@echo "  make mock"
	@echo "  make proto"
	@echo "  make evans"
	@echo "  make redis"
	@echo "  make upredis"
	@echo "  make help"
