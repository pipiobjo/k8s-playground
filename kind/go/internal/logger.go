package internal

import (
	"os"

	"github.com/sirupsen/logrus"
)

func init() {
	log := logrus.New()
	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(logrus.DebugLevel)
	log.SetFormatter(&logrus.TextFormatter{
		DisableColors: false,
		FullTimestamp: true,
	})
	// Log.SetReportCaller(true)
	// log.Debug("Logger initialized")

}
