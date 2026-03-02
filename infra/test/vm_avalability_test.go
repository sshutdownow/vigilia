//go:build ignore

package terratest

import (
	"context"
	"fmt"
	"net"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/yandex-cloud/go-genproto/yandex/cloud/compute/v1"
	ycsdk "github.com/yandex-cloud/go-sdk"
	"github.com/yandex-cloud/go-sdk/iamkey"
)

func TestVirtualMachineAvailability(t *testing.T) {
	// Опции Terraform
	terraformOptions := &terraform.Options{
		TerraformDir: "..",
	}

	// Инициализация и применение Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Получение выходных данных
	vmDevName := terraform.Output(t, terraformOptions, "vm_dev_name")
	vmDevAddress := terraform.Output(t, terraformOptions, "vm_dev_address")
	vmProdName := terraform.Output(t, terraformOptions, "vm_prod_name")
	vmProdAddress := terraform.Output(t, terraformOptions, "vm_prod_address")

	// Проверка имен ВМ
	assert.Equal(t, "vm-dev", vmDevName, "Dev VM name does not match")
	assert.Equal(t, "vm-prod", vmProdName, "Prod VM name does not match")

	// Проверка, что IP-адреса не пустые
	assert.NotEmpty(t, vmDevAddress, "Dev VM address should not be empty")
	assert.NotEmpty(t, vmProdAddress, "Prod VM address should not be empty")

	// Инициализация Yandex Cloud SDK для проверки существования ВМ
	ctx := context.Background()
	yc, err := ycsdk.Build(ctx, ycsdk.Config{
		Credentials: getYCToken(t), // Функция для получения токена
	})
	if err != nil {
		t.Fatalf("Failed to initialize Yandex Cloud SDK: %v", err)
	}

	// Проверка существования ВМ
	computeService := yc.Compute().Instance()
	instances, err := computeService.List(ctx, &compute.ListInstancesRequest{
		FolderId: os.Getenv("TF_VAR_folder_id"), // Укажите ваш Folder ID
	})
	if err != nil {
		t.Fatalf("Failed to list instances: %v", err)
	}

	vmDevFound := false
	vmProdFound := false
	for _, instance := range instances.Instances {
		if instance.Name == vmDevName {
			vmDevFound = true
		}
		if instance.Name == vmProdName {
			vmProdFound = true
		}
	}
	assert.True(t, vmDevFound, "Dev VM not found in Yandex Cloud")
	assert.True(t, vmProdFound, "Prod VM not found in Yandex Cloud")

	// Проверка доступности IP-адресов через ping
	err = pingAddress(vmDevAddress)
	assert.NoError(t, err, "Failed to ping Dev VM at %s", vmDevAddress)

	err = pingAddress(vmProdAddress)
	assert.NoError(t, err, "Failed to ping Prod VM at %s", vmProdAddress)
}

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

// Функция для выполнения ping
func pingAddress(address string) error {
	// Проверяем доступность IP через TCP-соединение (ping может быть заблокирован)
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:22", address), 15*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to %s: %v", address, err)
	}
	conn.Close()
	return nil
}
