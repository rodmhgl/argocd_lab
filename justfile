alias p := plan
alias a := apply
alias ap := apply_plan

working_directory := "."
plan_name := "tfplan"

default:
  @just --list

# Run infracost
infracost:
  @echo "Running infracost"
  infracost breakdown --path={{working_directory}} # --format json --out-file infracost.json
  @echo "Infracost completed"

# Run terraform init
init:
  @echo "Running terraform init"
  @terraform -chdir={{working_directory}} init
  @echo "Terraform init completed"

# Run terraform plan
plan: fmt init
  @echo "Running terraform plan"
  @terraform -chdir={{working_directory}} plan -out={{plan_name}}
  @echo "Terraform plan completed"

# Run terraform apply
apply: fmt init
  @echo "Running terraform apply"
  @terraform -chdir={{working_directory}} apply -auto-approve
  @echo "Terraform apply completed"

# Run terraform apply using the plan generated in the plan step
apply_plan: fmt init
  @echo "Running terraform apply using plan"
  @terraform -chdir={{working_directory}} apply -auto-approve {{plan_name}}
  @echo "Terraform apply using plan completed"

# Run terraform destroy
destroy: fmt init
  @echo "Running terraform destroy"
  @terraform -chdir={{working_directory}} destroy -auto-approve
  @echo "Terraform destroy completed"

# Remove .terraform directory, tfplan, and state backup files
clean: fmt
  @echo "Cleaning up generated files"
  @rm -rf {{working_directory}}/.terraform &&	rm -rf {{working_directory}}/{{plan_name}} && rm -rf {{working_directory}}/terraform.tfstate.backup
  @echo "Clean completed"

# Run terraform fmt
fmt:
  @echo "Running terraform fmt"
  @terraform -chdir={{working_directory}} fmt
  @echo "Terraform fmt completed"

# Run terraform validate
validate: fmt init
  @echo "Running terraform validate"
  @terraform -chdir={{working_directory}} validate
  @echo "Terraform validate completed"

# Start all AKS clusters with specified resource group
start_all_aks rg:
  @echo "Starting all AKS clusters across subscriptions"
  @az automation runbook start --automation-account-name AKS-Lab-Automation --name Start-AKS-Clusters --resource-group {{rg}}
  @echo "Start job initiated"

# Stop all AKS clusters with specified resource group
stop_all_aks rg:
  @echo "Stopping all AKS clusters across subscriptions"
  @az automation runbook start --automation-account-name AKS-Lab-Automation --name Stop-AKS-Clusters --resource-group {{rg}}
  @echo "Stop job initiated"

# Check job status
check_job_status rg:
  @echo "Checking automation job status"
  @az automation job list --automation-account-name AKS-Lab-Automation --resource-group {{rg}} --query "[?status=='Running']" -o table