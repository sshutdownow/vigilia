package terratest

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	httphelper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/yandex-cloud/go-genproto/yandex/cloud/k8s/v1"
	ycsdk "github.com/yandex-cloud/go-sdk"
	"github.com/yandex-cloud/go-sdk/iamkey"
)

// Функция для получения OAuth-токена
func getYCToken(t *testing.T) ycsdk.Credentials {
	key, err := iamkey.ReadFromJSONFile("../authorized_key.json")
	if err != nil {
		t.Fatalf("Failed to read authorized_key.json: %v", err)
	}

	credentials, err := ycsdk.ServiceAccountKey(key)
	if err != nil {
		t.Fatalf("Failed to get credentials: %v", err)
	}
	return credentials
}

func TestYandexK8sExistsAndRunning(t *testing.T) {
	folderID := os.Getenv("TF_VAR_folder_id")
	assert.NotEmpty(t, folderID, "ENV 'TF_VAR_folder_id' must be set")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "..",
	})

	// Инициализация и применение Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Получение выходных данных
	clusterID := terraform.Output(t, terraformOptions, "k8s_cluster_id")
	assert.NotEmpty(t, clusterID, "k8s_cluster_id should not be empty")

	ctx := context.Background()
	yc, err := ycsdk.Build(ctx, ycsdk.Config{
		Credentials: getYCToken(t),
	})
	assert.NoError(t, err)

	// Проверяем существование кластера k8s
	cluster, err := yc.Kubernetes().Cluster().Get(ctx, &k8s.GetClusterRequest{
		ClusterId: clusterID,
	})

	assert.NoError(t, err, "k8s cluster not found in YC folder %s", folderID)
	assert.Equal(t, k8s.Cluster_RUNNING, cluster.Status, "k8s cluster not in RUNNING state")
}

func TestArgoCDLogin(t *testing.T) {
	adminPassword := os.Getenv("ARGO_ADM_PASSWD")
	assert.NotEmpty(t, adminPassword, "ENV 'ARGO_ADM_PASSWD' must be set")

	// Опции Terraform
	terraformOptions := &terraform.Options{
		TerraformDir: "..",
	}

	// Инициализация и применение Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Получение выходных данных
	argocdDomain := terraform.Output(t, terraformOptions, "argocd_domain")

	assert.NotEmpty(t, argocdDomain, "Terraform output 'argocd_domain' should not be empty")

	loginUrl := fmt.Sprintf("https://%s/api/v1/session", argocdDomain)

	// Строгая проверка TLS-сертификата
	tlsConfig := tls.Config{
		InsecureSkipVerify: false,
		ServerName:         argocdDomain,
	}

	// Ждем балансировщик ~6 минут
	maxRetries := 25
	timeBetweenRetries := 15 * time.Second

	// Данные для авторизации. ArgoCD API ожидает JSON
	requestBody, _ := json.Marshal(map[string]string{
		"username": "admin",
		"password": adminPassword,
	})

	status := httphelper.HTTPDoWithRetry(
		t,
		"POST",
		loginUrl,
		requestBody,
		map[string]string{"Content-Type": "application/json"},
		200,
		maxRetries,
		timeBetweenRetries,
		&tlsConfig,
	)

	assert.Equal(t, 200, status, "ArgoCD API should return 200 on successful login")
}
