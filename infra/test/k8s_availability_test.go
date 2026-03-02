package terratest

import (
	"context"
	"os"
	"testing"

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

	assert.NoError(t, err, "Кластер не найден в каталоге %s", folderID)
	assert.Equal(t, k8s.Cluster_RUNNING, cluster.Status, "Кластер должен быть активен")
}
