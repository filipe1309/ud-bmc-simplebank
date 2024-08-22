package gapi

import (
	"fmt"

	db "github.com/filipe1309/ud-bmc-simplebank/db/sqlc"
	"github.com/filipe1309/ud-bmc-simplebank/pb"
	"github.com/filipe1309/ud-bmc-simplebank/token"
	"github.com/filipe1309/ud-bmc-simplebank/util"
	"github.com/filipe1309/ud-bmc-simplebank/worker"
)

// Server serves gRPC requests for our banking service.
type Server struct {
	pb.UnimplementedSimpleBankServer
	config          util.Config
	store           db.Store
	tokenMaker      token.Maker
	taskDistributor worker.TaskDistributer
}

// NewServer creates a new gRPC server.
func NewServer(config util.Config, store db.Store, taskDistributor worker.TaskDistributer) (*Server, error) {
	tokenMaker, err := token.NewPasetoMaker(config.TokenSymmetricKey)
	if err != nil {
		return nil, fmt.Errorf("cannot create token maker: %w", err)
	}

	server := &Server{
		config:     config,
		store:      store,
		tokenMaker: tokenMaker,
		taskDistributor: taskDistributor,
	}

	return server, nil
}
