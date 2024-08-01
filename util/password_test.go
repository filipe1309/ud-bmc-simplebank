package util

import (
	"testing"

	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
)

func TestPassword(t *testing.T) {
	password := RandomString(6)
	hashedPassword1, err := HashedPassword(password)

	t.Run("hashed password", func(t *testing.T) {
		require.NoError(t, err)
		require.NotEmpty(t, hashedPassword1)
	})

	t.Run("check password", func(t *testing.T) {
		err = CheckPassword(password, hashedPassword1)
		require.NoError(t, err)
	})

	t.Run("wrong password", func(t *testing.T) {
		wrongPassword := RandomString(7)
		err = CheckPassword(wrongPassword, hashedPassword1)
		require.EqualError(t, err, bcrypt.ErrMismatchedHashAndPassword.Error())
	})

	hashedPassword2, err := HashedPassword(password)

	t.Run("hashed password second time", func(t *testing.T) {
		require.NoError(t, err)
		require.NotEmpty(t, hashedPassword2)
		require.NotEqual(t, hashedPassword1, hashedPassword2)
	})
}
