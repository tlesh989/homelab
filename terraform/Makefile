default: test

init:
	terraform init
	
test:
	terraform fmt . 
	terraform validate .
	doppler run --name-transformer tf-var -- terraform plan

apply:
	terraform apply -auto-approve