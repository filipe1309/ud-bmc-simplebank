package util

import (
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

// HashedPassword returns the bcrypt hashed version of the password.
func HashedPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("error hashing password: %w", err)
	}
	return string(hash), nil
}

// CheckPassword checks if the provided password is correct.
func CheckPassword(password string, hashedPassword string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}
