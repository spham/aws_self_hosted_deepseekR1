package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformDeployment(t *testing.T) {
	t.Parallel()

	// Configuration des options Terraform
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"aws_region":     "eu-west-1",
			"ami_id":         "ami-0e2d98d2a1e9f0169",
			"key_name":       "test-key",
			"allowed_ip":     "0.0.0.0/0",
			"max_spot_price": "1.5",
		},
		NoColor: true,
	})

	// Nettoyage à la fin du test
	defer terraform.Destroy(t, terraformOptions)

	// Déploiement de l'infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Récupération des outputs
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	publicIP := terraform.Output(t, terraformOptions, "public_ip")
	region := terraform.Output(t, terraformOptions, "region")

	// Vérification que l'instance est en cours d'exécution
	instanceState := aws.GetEc2InstanceState(t, region, instanceID)
	assert.Equal(t, "running", instanceState)

	// Vérification que l'instance a une IP publique
	assert.NotEmpty(t, publicIP)

	// Vérification que les ports nécessaires sont ouverts
	// Port SSH (22)
	assert.True(t, isPortOpen(t, publicIP, 22, 30*time.Second))

	// Port UI (3000) - peut prendre plus de temps à être disponible
	assert.True(t, isPortOpen(t, publicIP, 3000, 60*time.Second))
}

// Fonction pour vérifier si un port est ouvert
func isPortOpen(t *testing.T, host string, port int, timeout time.Duration) bool {
	return aws.IsPortOpen(t, host, port, "tcp", timeout)
}
