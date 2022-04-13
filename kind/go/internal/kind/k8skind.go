package kind

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"text/template"

	myConfig "github.com/example/k8s-cli/internal/config"
	"github.com/example/k8s-cli/internal/docker"
	tpl "github.com/example/k8s-cli/internal/templates"

	// "github.com/example/k8s-cli/internal"
	kind "sigs.k8s.io/kind/cmd/kind/app"
	kindCMD "sigs.k8s.io/kind/pkg/cmd"
	kindLog "sigs.k8s.io/kind/pkg/log"
)

var logger kindLog.Logger
var stdin kindCMD.IOStreams
var cfg *myConfig.ConfigType

func init() {
	logger = kindCMD.NewLogger()
	stdin = kindCMD.StandardIOStreams()
	cfg = myConfig.Config
} //   -d \
//   --publish "${DOCKER_REGISTRY_PORT}:5000" \
//   --restart=always \
//   --name "${DOCKER_INTERNAL_REGISTRY_NAME}" \
//   --net=kind \
//   registry:2

func StartK8sKind() {
	fmt.Println("kind: create cluster " + cfg.ClusterName)

	k8sCfgFile := createKindConfig(cfg)
	kind.Run(logger, stdin, []string{"create", "cluster", "--name=" + cfg.ClusterName, "--config=" + k8sCfgFile.Name()})
	// remove file afterwards
	defer os.Remove(k8sCfgFile.Name())
}

func createKindConfig(cfg *myConfig.ConfigType) *os.File {
	tmpFile, err := os.CreateTemp(os.TempDir(), "*.yaml")
	if err != nil {
		fmt.Println(err)
	}

	cfgMap, err := template.New("foo").Parse(tpl.KindClusterConfigTpl)

	if err != nil {
		fmt.Println(err)
	}
	cfgMap.ExecuteTemplate(tmpFile, "foo", cfg)

	fmt.Println("Created File: " + tmpFile.Name())
	return tmpFile

}

func StartDockerRegistry() {

	docker.ListContainer()

	//   docker run \
	//   -d \
	//   --publish "${DOCKER_REGISTRY_PORT}:5000" \
	//   --restart=always \
	//   --name "${DOCKER_INTERNAL_REGISTRY_NAME}" \
	//   --net=kind \
	//   registry:2
	dockerRegistryStartContainer := exec.Command(
		"docker",
		"run",
		"-d",
		"--name="+cfg.ContainerRegistryName,
		"--publish="+strconv.Itoa(cfg.ContainerRegistryPort)+":5000",
		"--net=kind",
		"registry:2",
	)

	stdout1, err1 := dockerRegistryStartContainer.Output()
	if err1 != nil {
		fmt.Printf("Error during container registry %v", stdout1)
		fmt.Printf("Error output %v \n", err1.Error())
		return
	}

	// Print the output
	fmt.Println(string(stdout1))
}

func DeleteK8sKind() {
	fmt.Println("calling kind to delete cluster")
	kind.Run(logger, stdin, []string{"delete", "cluster", "--name=" + cfg.ClusterName})

}
