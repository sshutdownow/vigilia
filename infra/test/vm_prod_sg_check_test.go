package terratest

// Добавьте еще один файл vm_prod_sg_check_test.go и опишите в нем проверку наличия Security Group у виртуальной "prod"-машины.
// Также добавьте проверку на соответствие имени созданной Security Group с тем, что указано в terraform-файлах.

import (
	"context"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/yandex-cloud/go-genproto/yandex/cloud/compute/v1"
	ycvpc "github.com/yandex-cloud/go-genproto/yandex/cloud/vpc/v1"
	ycsdk "github.com/yandex-cloud/go-sdk"
	"os"
	"testing"
)

func TestVMProdSecurityGroupAvailability(t *testing.T) {
	folderID := os.Getenv("TF_VAR_folder_id")
	assert.NotEmpty(t, folderID, "ENV 'TF_VAR_folder_id' must be set")

	// Опции Terraform
	terraformOptions := &terraform.Options{
		TerraformDir: "..",
	}

	// Инициализация и применение Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Получение выходных данных
	vmProdName := terraform.Output(t, terraformOptions, "vm_prod_name")
	vmProdAddress := terraform.Output(t, terraformOptions, "vm_prod_address")
	vmProdSGName := terraform.Output(t, terraformOptions, "prod_sg_name")
	//  vmProdSGIds := terraform.OutputList(t, terraformOptions, "prod_vm_sg_ids")

	// Проверка имен ВМ
	assert.Equal(t, "vm-prod", vmProdName, "Prod VM name does not match")

	// Проверка, что IP-адреса не пустые
	assert.NotEmpty(t, vmProdAddress, "Prod VM address should not be empty")

	// Проверка на соответствие имени созданной Security Group
	assert.NotEmpty(t, vmProdSGName, "Prod SG name should not be empty")
	assert.Equal(t, "infra-network-prod-sg", vmProdSGName, "Prod SG name does not match")

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
		FolderId: folderID, // Укажите ваш Folder ID
		Filter:   fmt.Sprintf("name = '%s'", vmProdName),
	})
	if err != nil {
		t.Fatalf("Failed to list instances: %v", err)
	}

	ycSG, err := yc.VPC().SecurityGroup().List(ctx, &ycvpc.ListSecurityGroupsRequest{
		FolderId: folderID, // Укажите ваш Folder ID
		Filter:   fmt.Sprintf("name = '%s'", vmProdSGName),
	})

	if err != nil {
		t.Fatalf("Failed to list SecurityGroups: %v", err)
	}

	sgProdID := ""
	for _, sg := range ycSG.SecurityGroups {
		if sg.Name == vmProdSGName {
			sgProdID = sg.Id
		}
	}
	assert.NotEmpty(t, sgProdID, "Prod SG not found in Yandex Cloud")

	vmProdFound := false
	sgProdFound := false
AllFound:
	for _, instance := range instances.Instances {
		if instance.Name != vmProdName {
			continue
		}
		vmProdFound = true

		for _, nic := range instance.NetworkInterfaces {
			for _, sgID := range nic.SecurityGroupIds {
				if sgID == sgProdID {
					sgProdFound = true
					break AllFound
				}
			}
		}
	}

	assert.True(t, vmProdFound, "Prod VM not found in Yandex Cloud")
	assert.True(t, sgProdFound, "Prod SG not assigned to Prod VM")
}
