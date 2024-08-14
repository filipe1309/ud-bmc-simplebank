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
HTTP_SERVER_ADDRESS=0.0.0.0:8081 make server
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

Access Token: Used to access protected resources

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

### 29. Auto build & push docker image to AWS ECR with Github Actions

Amazon ECR: Elastic Container Registry

Create a new private repository in ECR:

```sh
aws ecr create-repository --repository-name simplebank
```

#### Push commands for simplebank

1. Retrieve an authentication token and authenticate your Docker client to your registry. Use the AWS CLI:

```sh
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

2. Build your Docker image using the following command. For information on building a Docker file from scratch see the instructions [here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-container-image.html) . You can skip this step if your image is already built:
```sh
docker build -t simplebank .
```

3. After the build completes, tag your image so you can push the image to this repository:

```sh
docker tag simplebank:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/simplebank:latest
```

4. Run the following command to push this image to your newly created AWS repository:

```sh
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/simplebank:latest
```

Connecting GitHub Actions To AWS Using OIDC

```sh
aws sts get-caller-identity
```
On the IAM console, add a new identity provider:
> https://token.actions.githubusercontent.com is the URL of the GitHub Actions OIDC provider
> 
> sts.amazonaws.com is the audience of the token

```sh
aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com
```

```sh
aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::123123123123:oidc-provider/token.actions.githubusercontent.com
```

Set a custom policy for the identity provider:
IAM > Access management > Roles > Create role > Custom trust policy

```sh
aws iam create-policy --policy-name github-actions-ecr-policy --policy-document file://policy.json
```

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Principal": {
				"Federated": "arn:aws:iam::123123123123:oidc-provider/token.actions.githubusercontent.com"
			},
			"Condition": {
				"StringLike": {
					"token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
					"token.actions.githubusercontent.com:sub": "repo:filipe1309/ud-bmc-simplebank:*"
				}
			}
		}
	]
}
```
> Replace `123123123123` with your AWS account ID and `filipe1309/ud-bmc-simplebank` with your GitHub repository


Role name: github-actions-ecr-role

Create a new policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ecr:ap-south-1:123123123123:repository/simplebank"
    },
    {
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
```

```sh
aws iam create-policy --policy-name github-actions-ecr-policy --policy-document file://policy.json
```

Add the policy to the role:
> IAM > Access management > Roles > github-actions-ecr-role > Add permissions > Attach policies > github-actions-ecr-policy

```sh
aws iam attach-role-policy --role-name github-actions-ecr-role --policy-arn arn:aws:iam::123123123123:policy/github-actions-ecr-policy
```

Add SecretsManagerReadWrite policy to the role:
> IAM > Roles > github-actions-ecr-role Add permissions > Attach policies > SecretsManagerReadWrite

```sh
aws iam attach-role-policy --role-name github-actions-ecr-role --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

### 30. How to create a production database on AWS RDS

Amazon RDS: Relational Database Service

Create a new database on RDS:

```sh
aws rds create-db-instance --db-instance-identifier simple-bank --db-instance-class db.t3.micro --engine postgres --master-username root --master-user-password secret --allocated-storage 20 --db-name simple_bank --vpc-security-group-ids sg-0a1b2c3d4e5f6g7h8 --availability-zone us-east-1a
```

Get the creadentionals:
```sh
aws rds describe-db-instances --db-instance-identifier simple-bank
```

Configure the security group to allow connections from anywhere:

```sh
aws ec2 authorize-security-group-ingress --group-id sg-0a1b2c3d4e5f6g7h8 --protocol tcp --port 5432 --cidr
```

Update the host and password in `migrationup` of `Makefile`:

```sh
migrate -path db/migration -database "postgresql://root:<rds_password>@<rds_endpoint>:5432/simple_bank" -verbose up
```

Then run:

```sh
make migrateup
```


### 31. Store & retrieve production secrets with AWS secrets manager

Instal aws cli:

```sh
brew install awscli
```

Instal jq:

```sh
brew install jq
```

```sh
aws configure
```
> Add your AWS Access Key ID, Secret Access Key, Default region name, Default output format

```sh
ls -l ~/.aws
```
> `config` and `credentials` files

```sh


Create a random token symmetric key:

```sh
openssl rand -hex 64 | head -c 32
```


Amazon Secrets Manager

Create a new secret:

```sh
aws secretsmanager create-secret --name simple_bank --description "Environment variables and secrets for Simple Bank" --secret-string '{"DB_DRIVER": "postgres", "DB_SOURCE": "postgresql://root:<rds_password>@<rds_endpoint>:5432/simple_bank", "HTTP_SERVER_ADDRESS": "0.0.0.0:8080", "ACCESS_TOKEN_DURATION": "15m", "TOKEN_SYMMETRIC_KEY": "<random_token>"}'
```

Get the secret:

```sh
aws secretsmanager get-secret-value --secret-id simple_bank
```

```sh
aws secretsmanager get-secret-value --secret-id simple_bank --query SecretString --output text
```

To get the secret in a key=value format and save it to env file:

```sh
aws secretsmanager get-secret-value --secret-id simple_bank --query SecretString --output text | jq -r 'to_entries | map("\(.key)=\(.value)")|.[]' > app.env
```

#### Test image from private ECR repository:


First, we need to login to the ECR:
```sh
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com
```

Then, we can pull the image:


```sh
docker pull <account_id>.dkr.ecr.us-east-1.amazonaws.com/simplebank:<tag>
```
> You can get the image url from AWS Console > Amazon ECR > Private registry > Repositories > simplebank


```sh
docker images # list images
```

```sh
docker run -p 8080:8080 <image_url>
```

### 32. Kubernetes architecture & How to create an EKS cluster on AWS

Kubernetes Architecture:

- Master Node: Control Plane - Manage worker nodes and Pods of the cluster
	- API Server: Frontend for the Kubernetes control plane
	- Scheduler: Assigns Pods to Nodes
	- Controller Manager: Runs controller processes, such as Node Controller, Job Controller, Endpoint Controller, Service Account & Token Controller
	- etcd: Key-Value store to store cluster data
	- Cloud Controller Manager: Interacts with cloud provider's API to manage resources, it has Node Controller, Route Controller, Service Controller, Volume Controller

- Worker Node: Data Plane
	- Kubelet Agent: Makes sure that containers are running in a Pod
	- Kube Proxy: Maintains network rules and allows communication between Pods
	- Container Runtime: Docker, containerd, CRI-O

Amazon EKS: Elastic Kubernetes Service

- Master Node: Managed by AWS
- Worker Node: Managed by you

#### EKS cluster:

Create a role for the EKS cluster with AmazonEKSClusterPolicy:
> IAM > Access management > Roles > Create role > AWS service > EKS

```sh
aws iam create-role --role-name AWSEKSClusterRole --assume-role-policy-document file://eks-trust-policy.json
```

Create an EKS cluster:
> IAM > Access management > Roles > AWSEKSClusterRole > Attach policies > AmazonEKSClusterPolicy

```sh
aws eks create-cluster --name simple-bank --role-arn arn:aws:iam::123123123123:role/AWSEKSClusterRole --resources-vpc-config subnetIds=subnet-0a1b2c3d4e5f6g7h8,securityGroupIds=sg-0a1b2c3d4e5f6g7h8
```

Get the cluster status:

```sh
aws eks describe-cluster --name simple-bank
```

Create a new role (AWSEKSNodeRole) with AmazonEKS_CNI_Policy, AmazonEKSWorkerNodePolicy, and AmazonEC2ContainerRegistryReadOnly policies:
> IAM > Access management > Roles > Create role > AWS service > EC2

```sh
aws iam create-role --role-name AWSEKSNodeRole --assume-role-policy-document file://eks-trust-policy.json
```

Create a node group:

```sh
aws eks create-nodegroup --cluster-name simple-bank --nodegroup-name simple-bank-ng --node-role arn:aws:iam::123123123123:role/AWSEKSNodeRole --subnets subnet-0a1b2c3d4e5f6g7h8 --instance-types t3.micro --disk-size 20 --scaling-config minSize=1,maxSize=2,desiredSize=1
```

### 33. How to use kubectl &amp; k9s to connect to a kubernetes cluster on AWS EKS

Kubectl: Kubernetes Command Line Tool

```sh
brew install kubectl
kubectl version --client
```

Verify kubectl configuration:

```sh
kubectl cluster-info
```

Add user group permissions to allow your IAM user to access the EKS cluster:
> IAM > Access management > Users > github-cli > Groups > [Select the group] > Add permissions > Create policy > JSON > Policy name: EKSFullAccess

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "eks:*",
			"Resource": "*"
		}
	]
}
```sh

Get the kubeconfig file and update the `~/.kube/config` file:

```sh
aws eks update-kubeconfig --name simple-bank --region us-east-1
cat ~/.kube/config
```

To change to another cluster:

```sh
kubectl config get-contexts
kubectl config use-context <context_name>
```

Verify the connection:

```sh
kubectl cluster-info
```

If you get the error: You must be logged in to the server (Unauthorized), then add designated_user to the ConfigMap if cluster_creator is an IAM user
:

```sh
aws sts get-caller-identity # verify which user you are using
```

Create a new access key for the root:
> IAM > Access management > Users > root > Security credentials > Create access key

```sh
aws iam create-access-key --user-name root
```

Add the access key to the aws cli:

```sh
vi ~/.aws/credentials
```

Test with:

```sh
kubectl get nodes
```

To switch to another user:

```sh
export AWS_PROFILE=github
export AWS_PROFILE=default
```

#### To allow github user to access the EKS cluster:

```sh
touch aws-auth.yaml
```

Configure the `aws-auth.yaml` file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::123123123123:user/github-cli
      username: aws-cli
      groups:
        - system:masters
```

Apply the configuration:

```sh
kubectl apply -f eks/aws-auth.yaml
```

#### Other commands:


```sh
kubectl get services
kubectl get pods
kubectl get deployments
kubectl get nodes
kubectl get namespaces
```

K9s: Kubernetes CLI To Manage Your Clusters In Style

```sh
brew install derailed/k9s/k9s
```

```sh
k9s
```

### 34. How to deploy a web app to Kubernetes cluster on AWS EKS

Create a new deployment file:

```sh
touch eks/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-bank-api-deployment
  labels:
    app: simple-bank-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple-bank-api
  template:
    metadata:
      labels:
        app: simple-bank-api
    spec:
      containers:
      - name: simple-bank-api
        image: 123123123123.dkr.ecr.us-east-1.amazonaws.com/simplebank:latest
        ports:
        - containerPort: 8080
```

```sh
kubectl apply -f eks/deployment.yaml
```

In k9s, access the deployment and check the logs:

`describe` the deployment pod `simple-bank-api-deployment-<id>` and check the logs  
If you find `FailedScheduling`, then you need to adjust the capacity (Min, Max, Desired) of the node group. (Auto Scaling group)

Other problems is that our instance type t3.micro can have on 4 pods running at the same time, you can verify that with ENI (Elastic Network Interface) and IP addresses:

```
# Mapping is calculated from AWS EC2 API using the following formula:
# * First IP on each ENI is not used for pods
# * +2 for the pods that use host-networking (AWS CNI and kube-proxy)
#
#   # of ENI * (# of IPv4 per ENI - 1) + 2
#
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html#AvailableIpPerENI
...
t3.micro 4
...
```

And the eks cluster already has 4 pods running.

To fix that we need to upgrade the instance type to t3.small:

First delete the node group:

```sh
aws eks delete-nodegroup --cluster-name simple-bank --nodegroup-name simple-bank-ng
```

Then create a new node group with t3.small:

```sh
aws eks create-nodegroup --cluster-name simple-bank --nodegroup-name simple-bank-ng --node-role arn:aws:iam::123123123123:role/AWSEKSNodeRole --subnets subnet-0a1b2c3d4e5f6g7h8 --instance-types t3.small --disk-size 10 --scaling-config minSize=0,maxSize=2,desiredSize=1
```

Then apply the deployment again:

```sh
kubectl apply -f eks/deployment.yaml
```

Now we need to create a service to expose the deployment:

```sh
touch eks/service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: simple-bank-api-service
spec:
  selector:
    app: simple-bank-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
	type: LoadBalancer
```

```sh
kubectl apply -f eks/service.yaml
```

```sh
kubectl get services
```

```sh
nslookup <service_external_ip>
```

### 35. Register a domain &amp; set up A-record using Route53

Amazon Route 53: Domain Name System (DNS) web service

Register a new domain:

```sh
aws route53domains register-domain --domain-name simplebank.io --duration-in-years 1 --auto-renew
```

Get the domain details:

```sh
aws route53domains get-domain-detail --domain-name simplebank.io
```

Create a new A (address) record, to route traffic to the EKS cluster:
> Route 53 > Hosted zones > simplebank.io > Create record set > Type: A - IPv4 address > Alias: Yes > Alias target: Load balancer

```sh
aws route53 change-resource-record-sets --hosted-zone-id Z123123123123 --change-batch file://route53/change-resource-record-sets.json
```

With Route traffic to "Alias to Network Load Balancer"

```json
{
	"Comment": "Update record to route traffic to the EKS cluster",
	"Changes": [
		{
			"Action": "UPSERT",
			"ResourceRecordSet": {
				"Name": "api.simplebank.io",
				"Type": "A",
				"AliasTarget": {
					"HostedZoneId": "Z123123123123",
					"DNSName": "<simple-bank-api-service-id>.us-east-1.elb.amazonaws.com",
					"EvaluateTargetHealth": false,
					"Region": "us-east-1"
				}
			}
		}
	]
}
```

```sh
nslookup api.simplebank.io
```

### 36. How to use Ingress to route traffics to different services in Kubernetes

Now ou service is exposed to the internet by setting its type to LoadBalancer, and adding its external IP to the A record in Route 53.

This is fine as long as we just have one service, but if we have multiple services, we need to create a lot of A records in Route 53.

To solve this problem, we can use an Ingress Controller, which will allow us to create a single A record in Route 53, and then route traffic to the correct service based on the URL path. Ingress also provides SSL termination, load balancing, and name-based virtual hosting.

First change the service type to ClusterIP:

```sh
kubectl apply -f eks/service.yaml
```

Then create a new Ingress:

```sh
touch eks/ingress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-bank-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: api.simple-bank.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: simple-bank-api-service
                port:
                  number: 80

```

```sh
kubectl apply -f eks/ingress.yaml
```

```sh
kubectl get ingress
```

```sh
nslookup api.simple-bank.io
```

Nginx Ingress Controller:

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml
```

```sh
kubectl get pods -n ingress-nginx
```

Update the A record in Route 53 to point to the Ingress Address URL:
> Route 53 > Hosted zones > simplebank.io > Update record set > Type: A - IPv4 address > Alias: Yes > Alias target: Ingress Address

```sh
aws route53 change-resource-record-sets --hosted-zone-id Z123123123123 --change-batch file://route53/change-resource-record-sets-ingress.json
```

```json
{
	"Comment": "Update record to route traffic to the Ingress Controller",
	"Changes": [
		{
			"Action": "UPSERT",
			"ResourceRecordSet": {
				"Name": "api.simplebank.io",
				"Type": "A",
				"AliasTarget": {
					"HostedZoneId": "Z123123123123",
					"DNSName": "<ingress-address-id>.us-east-1.elb.amazonaws.com",
					"EvaluateTargetHealth": false,
					"Region": "us-east-1"
				}
			}
		}
	]
}
```

```sh
nslookup api.simplebank.io
```

### 37. Auto issue &amp; renew TLS certificates with cert-manager and Let's Encrypt

Cert-Manager: Kubernetes certificate management controller

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.2/cert-manager.yaml
```

Create a new ICME (Issuer) for Let's Encrypt:

```sh
touch eks/issuer.yaml
```

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: user@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-account-private-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
```

```sh
kubectl apply -f eks/issuer.yaml
```

After this you need to update the Ingress to use the TLS certificate:

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-bank-ingress
	anotations:
		cert-manager.io/cluster-issuer: letsencrypt
spec:
  ingressClassName: nginx
  rules:
    - host: api.simple-bank.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: simple-bank-api-service
                port:
                  number: 80
	tls:
		- hosts:
			- api.simple-bank.io
		secretName: simple-bank-api-cert
```

```sh
kubectl apply -f eks/ingress.yaml
```

### 38. Automatic deploy to Kubernetes with Github Action

Get last stable version of kubectl:

```sh
curl -L https://storage.googleapis.com/kubernetes-release/release/stable.txt
```

## Section 4: Advanced Backend Topics [Sessions + gRPC]

### 39. How to manage user session with refresh token

Session Management (access token (10-15 min) + refresh token (1-7 days))

- Access Token: Short-lived token to access protected resources
- Refresh Token: Long-lived token to get a new access token


```
Client                                               Server
	| 1. POST /users/login                               |
	| -------------------------------------------------> |
	| {username: "user1", password: "password1"}         |
	|                                                    |
	|                                       Signed Token |
	| <------------------------------------------------- |
	|               200 OK {access_token, refresh_token} | JWT, PASETO,...
	|                                                    |
	| 2. GET /accounts                                   |
	| -------------------------------------------------> |
	| Authorization: Bearer access_token                 |
	|                                                    |
	|                                       Verify Token |
	| <------------------------------------------------- |
	|                        200 OK [account1, account2] |
	|                                                    |
	| After access_token expires...                      |
	|                                                    |
	| 3. POST /tokens/renew-acess                        |
	| -------------------------------------------------> |
	| Authorization: Bearer refresh_token                |
	|                                                    |
	|                                       Verify Token | is blocked?
	| <------------------------------------------------- |
	|               200 OK {access_token, refresh_token} |
```

Add a new migration to create a new table for sessions:

```sh
migrate create -ext sql -dir db/migration -seq add_sessions 
# OR make migration-create name=add_sessions
```

### 40. Generate DB documentation page and schema SQL dump from DBML

#### DBDocs: Generate beautiful documentation for your database

```sh
npm install -g dbdocs
dbdocs
```
```sh
touch doc/db.dbml
```

```dbml
Project simple_bank {
  database_type: 'PostgreSQL'
  Note: '''
    # Simple Bank Database
  '''
}

Table users as U {
  username varchar [pk]
  hashed_password varchar [not null]
  full_name varchar [not null]
  email varchar [unique, not null]
  password_changed_at timestamptz [not null, default: '0001-01-01 00:00:00Z']
  created_at timestamptz [not null, default: `now()`]
}
```

```sh
dbdocs build doc/db.dbml
```

```sh
dbdocs password --set secret --project simple_bank
```

to remove a project:

```sh
dbdocs remove simple_bank
```

#### DBML CLI: Generate SQL schema dump from DBML

```sh
npm install -g @dbml/cli
dbml2sql --postgres -o db/schema.sql doc/db.dbml
```

### 41. Introduction to gRPC

gRPC: Remote Procedure Call (RPC) framework

- Protocol Buffers: Interface Definition Language (IDL) to define services and messages
- HTTP/2: Transport protocol
- Bidirectional Streaming: Multiple requests and responses in parallel
- Code Generation: Generate client and server code in multiple languages

How gRPC works:

1. Define API & data structures in `.proto` file
2. Generate server & client code (stubs) using `protoc` compiler
3. Implement server code
4. Call server from client

Example:

`welcome.proto`:
```proto
syntax = "proto3";

message HelloRequest {
	string name = 1;
}

message HelloResponse {
	string greet = 1;
}

service WelcomeService {
	rpc SayHello (HelloRequest) returns (HelloResponse);
}
```

`welcome.rs`:
```rust
pub struct HelloRequest {
	pub name: ::std::string::String,
}

pub struct HelloResponse {
	pub greet: ::std::string::String,
}

pub struct WelcomeServiceClient {
	client: ::grpcio::Client,
}

pub trait WelcomeService {
	fn say_hello(&mut self, req: HelloRequest, sink: ::grpcio::UnarySink<HelloResponse>);
}
```

`welcome.go`:
```go
type HelloRequest struct {
	Name string `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
}

type HelloResponse struct {
	Greet string `protobuf:"bytes,1,opt,name=greet,proto3" json:"greet,omitempty"`
}

type WelcomeServiceClient interface {
	SayHello(*HelloRequest) (*HelloResponse, error)
}

type WelcomeServiceServer interface {
	SayHello(*HelloRequest) (*HelloResponse, error)
}
```

Why gRPC:

- Performance: HTTP/2, binary serialization, bidirectional streaming
- Strong Typing: Protocol Buffers RPC definition shared between client and server
- Code Generation: Generate client and server code

Types of gRPC:

- Unary RPC: Simple request and response
- Server Streaming RPC: Server sends multiple responses after receiving a request
- Client Streaming RPC: Client sends multiple requests and server sends a single response
- Bidirectional Streaming RPC: Both client and server send multiple requests and responses

gRPC Gateway: Serve gRPC and RESTful HTTP JSON API on the same port


### 42. Define gRPC API and generate Go code with protobuf

Protocol Buffer Compiler

```sh
brew install protobuf
```

```sh
protoc --version
```

Go plugins for the protocol compiler:

```sh
go install google.golang.org/protobuf/cmd/protoc-gen-go
protoc-gen-go --version
```

```sh
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
protoc-gen-go-grpc --version
```

Create proto files, ant then run:

```sh
protoc --proto_path=proto --go_out=pb --go_opt=paths=source_relative \
    --go-grpc_out=pb --go-grpc_opt=paths=source_relative \
    proto/*.proto
```

this will generate the `pb` package with the Go code.

```sh
go mod tidy
```

### 43. How to run a golang gRPC server and call its API

```sh
go run main.go
```

Evans: gRPC CLI

```sh
brew tap ktr0731/evans
brew install evans
```

```sh
evans --host localhost --port 9090 -r repl # default port is 50051
```

```sh
show service
package pb
service SimpleBank
```

```sh
# call pb.SimpleBank.CreateUser
call CreateUser
```

```sh
exit
```

### 45. gRPC Gateway: write code once, serve both gRPC & HTTP requests

- A plugin for the Google protocol buffer compiler `protoc`
- Generate HTTP proxy codes from protobuf
- Translate RESTful HTTP JSON API to gRPC
 - In-process translation: only for unary RPC
 - Separate proxy server: both for unary and streaming RPC

```mermaid
graph LR
		A[Client] -->|HTTP| B[API Gateway]
		B -->|gRPC| C[Service]
		C -->|HTTP| B
```

On `tools/tools.go`:

```go
// +build tools

package tools

import (
    _ "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway"
    _ "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2"
    _ "google.golang.org/grpc/cmd/protoc-gen-go-grpc"
    _ "google.golang.org/protobuf/cmd/protoc-gen-go"
)
```

```sh
go mod tidy
```

```sh
go install \
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway \
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2 \
	google.golang.org/protobuf/cmd/protoc-gen-go \
	google.golang.org/grpc/cmd/protoc-gen-go-grpc
```

Copy:

google/api/annotations.proto  
google/api/field_behavior.proto  
google/api/http.proto  
google/api/httpbody.proto  

from https://github.com/googleapis/googleapis  
