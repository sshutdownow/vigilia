package test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"://github.com/iamkey"

	ycsdk "github.com/yandex-cloud/go-sdk"
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

func TestYandexK8sLifecycle(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "..",
		EnvVars: map[string]string{
			"YC_SERVICE_ACCOUNT_KEY_FILE": "../authorized_key.json",
		},
	}

	ctx := context.Background()
	creds := getYCToken(t)
	yc, err := ycsdk.Build(ctx, ycsdk.Config{
		Credentials: creds,
	})
	if err != nil {
		t.Fatalf("Failed to initialize Yandex Cloud SDK: %v", err)
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	endpoint := terraform.Output(t, terraformOptions, "k8s_external_v4_endpoint")
	caCert := terraform.Output(t, terraformOptions, "k8s_ca_certificate")

	token, err := creds.IAMToken(ctx)
	if err != nil {
		t.Fatalf("Failed to get IAM token: %v", err)
	}

	tmpFile, err := os.CreateTemp("", "kubeconfig-*.yaml")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	kubeconfigPath := tmpFile.Name()
	defer os.Remove(kubeconfigPath)
	defer tmpFile.Close()

	kubeconfigContent := fmt.Sprintf(`
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: %s
    server: %s
  name: yc-cluster
contexts:
- context:
    cluster: yc-cluster
    user: yc-sdk-user
  name: default
current-context: default
users:
- name: yc-sdk-user
  user:
    token: %s
`, caCert, endpoint, token.AccessToken)

	if _, err := tmpFile.Write([]byte(kubeconfigContent)); err != nil {
		t.Fatalf("Failed to write kubeconfig: %v", err)
	}

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfigPath, "default")

	k8s.WaitUntilAllNodesReady(t, kubectlOptions, 90, 10*time.Second) // 15 минут

	// API отвечает и есть системный неймспейс
	namespaces := k8s.GetAllNamespaces(t, kubectlOptions)
	assert.Contains(t, namespaces, "kube-system")

	fmt.Printf("Success! Cluster at %s is fully operational.\n", endpoint)
}
