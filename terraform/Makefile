default: test

init:
	terraform init
	
test:
	terraform fmt . 
	terraform validate .
	terraform plan

apply:
	terraform apply -auto-approve