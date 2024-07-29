
<a name="readme-top"></a>

# <p align="center">A Simple Bank</p>

<p align="center">
    <img src="https://img.shields.io/badge/Code-Go-informational?style=flat-square&logo=go&color=00ADD8" alt="Go" />
    <img src="https://img.shields.io/badge/Tools-PostgreSQL-informational?style=flat-square&logo=postgresql&color=4169E1&logoColor=4169E1" alt="PostgreSQL" />
    <img src="https://img.shields.io/badge/Tools-Docker-informational?style=flat-square&logo=docker&color=2496ED" alt="Docker" />
    <img src="https://img.shields.io/badge/Tools-Kubernetes-informational?style=flat-square&logo=kubernetes&color=326CE5" alt="Kubernetes" />
</p>

## 💬 About

This project was developed following Udemy's "[Backend Master Class [Golang + Postgres + Kubernetes + gRPC]](https://www.udemy.com/course/backend-master-class-golang-postgresql-kubernetes/)" class.

The project is a simple bank system that allows you to create accounts, deposit and withdraw money, and transfer money between accounts.

![Database](db_simple-bank.png)

Notes taken during the course are in the [notes](notes.md) file.

## :computer: Technologies

- [Go](https://golang.org/)
- [PostgreSQL](https://www.postgresql.org/)
- [Lib pq](https://github.com/lib/pq)
- [SQLC v2](https://sqlc.dev/)
- [Testify](https://github.com/stretchr/testify)
- [gRPC](https://grpc.io/)
- [Docker](https://www.docker.com/)
- [Kubernetes](https://kubernetes.io/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## :scroll: Requirements

- [Docker](https://www.docker.com/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## :cd: Installation

```sh
git clone git@github.com:filipe1309/ud-bmc-simplebank.git
```

```sh
cd ud-bmc-simplebank
```

```sh
make install
```
> This will run the commands: `make createdb` and `make migrateup`
> This will install the project dependencies and create the database.
> The database will be available at `localhost:5432` with
> - user: `root`
> - password: `secret`
> - database: `simple_bank`


<p align="right">(<a href="#readme-top">back to top</a>)</p>

## :runner: Running

```sh
make run
```

> Access http://localhost

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ## :white_check_mark: Tests

After up the container:

```sh
docker-compose exec -t {{ CONTAINER_SERVICE_NAME }} ./vendor/bin/phpunit
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate. -->

## :memo: License

[MIT](https://choosealicense.com/licenses/mit/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## 🧙‍♂️ About Me

<p align="center">
    <a style="font-weight: bold" href="https://github.com/filipe1309/">
    <img style="border-radius:50%" width="100px; "src="https://github.com/filipe1309.png"/>
    </a>
</p>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<p align="center">
    Done with&nbsp;&nbsp;♥️&nbsp;&nbsp;by <a style="font-weight: bold" href="https://github.com/filipe1309/">Filipe Leuch Bonfim</a> 🖖
</p>

---

## :clap: Acknowledgments

- [Simple Bank Repo](https://github.com/techschool/simplebank)
- [Backend Master Class [Golang + Postgres + Kubernetes + gRPC]](https://www.udemy.com/course/backend-master-class-golang-postgresql-kubernetes/)
- [Simple Bank DBDocs](https://dbdocs.io/techschool.guru/simple_bank)
- [TablePlus](https://tableplus.com/)
- [ShubcoGen Template™](https://github.com/filipe1309/shubcogen-template)
- [Golang Migrate CLI Repo](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate)
- [DBML](https://dbml.dbdiagram.io/docs/)
- [Gorm](https://gorm.io/)
- [SQLX](https://jmoiron.github.io/sqlx/)
- [SQLC](https://sqlc.dev/)
- [Lib pq](https://github.com/lib/pq)
- [Testify](https://github.com/stretchr/testify)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

