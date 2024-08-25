package mail

import (
	"testing"

	"github.com/filipe1309/ud-bmc-simplebank/util"
	"github.com/stretchr/testify/require"
)

func TestSendEmailWithMailTrap(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping test in short mode.")
	}
	config, err := util.LoadConfig("../")
	require.NoError(t, err)

	sender := NewMailTrapSender(config.EmailSenderName, config.EmailSenderUserName, config.EmailSenderAddress, config.EmailSenderPassword)

	subject := "Test email 2"
	content := `
		<h1>Test email</h1>
		<p>This is a test email.</p>
	`
	to := []string{"johndoe@email.com"}
	attachFiles := []string{"../README.md"}

	err = sender.SendEmail(subject, content, to, nil, nil, attachFiles)
	require.NoError(t, err)
}
