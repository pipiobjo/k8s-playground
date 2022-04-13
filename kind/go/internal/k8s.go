package internal

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"text/template"
	"time"

	myConfig "github.com/example/k8s-cli/internal/config"
	kind "github.com/example/k8s-cli/internal/kind"
	tpl "github.com/example/k8s-cli/internal/templates"
)

var cfg *myConfig.ConfigType

func init() {
	cfg = myConfig.Config
}

func Start() {
	if cfg.ClusterFlavour == "kind" {
		// kind.StartK8sKind()
		// kind.StartDockerRegistry()
		installIngress()
		installMetricServer()
	}
}

func Delete() {
	if cfg.ClusterFlavour == "kind" {
		kind.DeleteK8sKind()
	}

}

func Restart() {
	Delete()
	Start()
}

func installIngress() {

	applyIngressCMD := exec.Command(
		"kubectl",
		"apply",
		"--filename=\"https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml\"",
	)
	executeAndLog(applyIngressCMD)
	fmt.Println("waiting for ingress to be ready")
	time.Sleep(3 * time.Second)
	waitForDeploymentCMD := exec.Command(
		"kubectl",
		"wait",
		"pod",
		"--namespace=ingress-nginx",
		"--selector=app.kubernetes.io/component=controller",
		"--for=condition=ready",
		"--timeout=190s",
	)

	executeAndLog(waitForDeploymentCMD)

}

func installMetricServer() {
	installMetricServerCMD := exec.Command(
		"kubectl",
		"apply",
		"--filename=\"https://github.com/kubernetes-sigs/metrics-server/releases/download/metrics-server-helm-chart-3.8.2/components.yaml\"",
	)
	executeAndLog(installMetricServerCMD)

	patchMetricServer()

	fmt.Println("waiting for metric server to be ready")
	time.Sleep(3 * time.Second)
	waitForDeploymentCMD := exec.Command(
		"kubectl",
		"wait",
		"deployment",
		"--namespace=kube-system",
		"--selector=k8s-app=metrics-server",
		"--for=condition=available",
		"--timeout=190s",
	)
	executeAndLog(waitForDeploymentCMD)
}

func patchMetricServer() {
	tmpFile, err := os.CreateTemp(os.TempDir(), "*.yaml")
	if err != nil {
		fmt.Println(err)
	}

	cfgMap, err := template.New("foo").Parse(tpl.MetrikServerPatchTpl)

	if err != nil {
		fmt.Println(err)
	}
	cfgMap.ExecuteTemplate(tmpFile, "foo", cfg)

	fmt.Println("Created File: " + tmpFile.Name())

	installMetricServerCMD := exec.Command(
		"kubectl",
		"patch",
		"deployment",
		"metrics-server",
		"--namespace=kube-system",
		"--patch-file="+tmpFile.Name(),
	)
	executeAndLog(installMetricServerCMD)

}

func executeAndLog(cmd *exec.Cmd) {
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		fmt.Println(fmt.Sprint(err) + ": " + stderr.String())
		return
	}
	fmt.Println("Result: " + out.String())
}
