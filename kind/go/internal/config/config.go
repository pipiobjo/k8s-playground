package config

import (
	"fmt"

	"github.com/spf13/viper"
)

// Create private data struct to hold config options.
type ConfigType struct {
	ClusterFlavour        string `yaml: cluster-flavour` // kind or maybe k3d
	ClusterName           string `yaml:"cluster-name"`
	ContainerRegistryPort int    `yaml:"container-registry-port"`
	ContainerRegistryName string `yaml:"container-registry-name"`
	KubernetsHttpPort     int    `yaml: "kubernetes-http-port"`
	KubernetsHttpsPort    int    `yaml: "kubernetes-https-port"`
}

// Create a new config instance.
var (
	Config *ConfigType
)

// Read the config file from the current directory and marshal
// into the conf config struct.
func getConf() *ConfigType {
	viper.AddConfigPath(".")
	viper.SetConfigName("config")
	err := viper.ReadInConfig()

	if err != nil {
		fmt.Println("No config file found", err)
	}

	conf := &ConfigType{}
	err = viper.Unmarshal(conf)
	if err != nil {
		// Logger.Errorf("unable to decode into config struct, %v", err)
	}

	if conf.ClusterName == "" {
		conf.ClusterName = "myscope"
	}

	if conf.ClusterFlavour == "" {
		conf.ClusterFlavour = "kind"
	}

	if conf.ContainerRegistryName == "" {
		conf.ContainerRegistryName = "myscope-kind-registry"
	}

	if conf.ContainerRegistryPort == 0 {
		conf.ContainerRegistryPort = 5000
	}

	if conf.KubernetsHttpPort == 0 {
		conf.KubernetsHttpPort = 30080
	}

	if conf.KubernetsHttpsPort == 0 {
		conf.KubernetsHttpsPort = 30443
	}

	return conf
}

// Initialization routine.
func init() {
	// Retrieve config options.
	Config = getConf()
}
