jammy_file := ubuntu-server-2204

ubuntu-jammy:
	op inject -f -i http/${jammy_file}.tpl -o http/user-data
	packer fmt ${jammy_file}.pkr.hcl
	packer validate ${jammy_file}.pkr.hcl
	PACKER_LOG=1 packer build ${jammy_file}.pkr.hcl