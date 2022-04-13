package docker

import (
	"context"
	"fmt"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

func CreateNewContainer(image string) (string, error) {
	cli, err := client.NewEnvClient()
	if err != nil {
		fmt.Println("Unable to create docker client")
		panic(err)
	}

	hostBinding := nat.PortBinding{
		HostIP:   "0.0.0.0",
		HostPort: "8000",
	}
	containerPort, err := nat.NewPort("tcp", "80")
	if err != nil {
		panic("Unable to get the port")
	}

	portBinding := nat.PortMap{containerPort: []nat.PortBinding{hostBinding}}

	networkingConfig := make(map[string]*network.EndpointSettings)

	// sample
	// https://medium.com/@Frikkylikeme/controlling-docker-with-golang-code-b213d9699998
	// https://godoc.org/github.com/docker/docker/api/types/network#NetworkingConfig

	// ContainerCreate(
	// 	ctx context.Context,
	// 	config *container.Config,
	// 	hostConfig *container.HostConfig,
	// 	networkingConfig *network.NetworkingConfig,
	// 	platform *specs.Platform,
	// 	containerName string
	// )
	cont, err := cli.ContainerCreate(
		context.Background(),
		&container.Config{
			Image: image,
		},
		&container.HostConfig{
			PortBindings: portBinding,
		},
		&network.NetworkingConfig{EndpointsConfig: networkingConfig},
		nil,
		"mycontainer",
	)

	if err != nil {
		panic(err)
	}

	cli.ContainerStart(context.Background(), cont.ID, types.ContainerStartOptions{})
	fmt.Printf("Container %s is started", cont.ID)
	return cont.ID, nil
}
