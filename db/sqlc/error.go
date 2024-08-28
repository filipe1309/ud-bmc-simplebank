package db

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const (
	ForeignKeyViolation = "23503"
	UniqueViolation     = "23505"
)

var (
	ErrRecordNotFound  = pgx.ErrNoRows
	ErrUniqueViolation = &pgconn.PgError{Code: UniqueViolation}
)

func ErrorCode(err error) string {
	var pgxErr *pgconn.PgError
	if errors.As(err, &pgxErr) {
		fmt.Println(">>",pgxErr.ConstraintName)
		return pgxErr.Code
	}
	return ""
}
