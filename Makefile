DEFAULT_OUTPUT_DIR = .

.PHONY: all help plan apply apply_plan destroy clean fmt validate

help:
	@echo "Terraform Makefile"
	@echo "------------------------------"
	@echo "Available targets:"
	@echo "  make plan          - Run terraform plan"
	@echo "  make apply         - Run terraform apply"
	@echo "  make apply_plan    - Run terraform apply using plan generated with make plan"
	@echo "  make destroy       - Run terraform destroy"
	@echo "  make clean         - Remove generated files"
	@echo "  make fmt           - Format Terraform configuration"
	@echo "  make validate      - Validate Terraform configuration"
	@echo ""
	@echo "Examples:"
	@echo "  make plan OUTPUT=./terraform/path"
	@echo "  make apply OUTPUT=./terraform/path"
	@echo "  make destroy OUTPUT=./terraform/path"

all: help

plan:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	echo "Running terraform plan in $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform init && terraform plan -out tfplan

apply:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	make fmt; \
	echo "Running terraform apply in $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform init && terraform apply -auto-approve

apply_plan:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	make fmt; \
	echo "Running terraform apply with tfplan in $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform init && terraform apply tfplan

destroy:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	make fmt; \
	echo "Running terraform destroy in $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform init && terraform apply -destroy -auto-approve

clean:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	make fmt; \
	echo "Cleaning $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && rm -rf ./.terraform &&	rm -rf tfplan && rm -rf terraform.tfstate.backup

fmt:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	echo "fmt'ing $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform fmt

validate:
	@OUTPUT_DIR=$${OUTPUT:-$(DEFAULT_OUTPUT_DIR)}; \
	make fmt; \
	echo "Validating $$OUTPUT_DIR"; \
	cd $$OUTPUT_DIR && terraform init && terraform validate