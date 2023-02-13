huma:
	ansible-playbook -b main.yml --limit huma --ask-pass

unifi:
	ansible-playbook -b main.yml --limit unifi --ask-pass

reqs:
	ansible-galaxy install -r requirements.yml

forcereqs:
	ansible-galaxy install -r requirements.yml --force

vault_pass:
	op read op://CLI/HOMELAB_VAULT_PASS/password > .vault_pass

decrypt:
	ansible-vault decrypt vars/vault.yml

encrypt:
	ansible-vault encrypt vars/vault.yml

gitinit:
	@./scripts/git-init.sh
	@echo "ansible vault pre-commit hook installed"
	@echo "don't forget to create a .vault_pass"
