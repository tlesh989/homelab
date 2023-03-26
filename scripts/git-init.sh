#!/usr/bin/env bash
# sets up a pre-commit hook to ensure that vault.yml is encrypted
# https://github.com/ironicbadger/infra/blob/7acc044cd898a9c8471cd77810145c0aedebf68b/git-init.sh
#
# credit goes to nick busey from homelabos for this neat little trick
# https://gitlab.com/NickBusey/HomelabOS/-/issues/355
pwd
if [ -d .git/ ]; then
    rm .git/hooks/pre-commit
cat <<EOT >> .git/hooks/pre-commit
ENCRYPTED_FILES=("vars/vault.yml" "envrc")

for file in "\${ENCRYPTED_FILES[@]}"
do
    if ( git show :"\$file" | grep -q "\$ANSIBLE_VAULT;" ); then
        printf "\e[32m\$file encrypted. Safe to commit.\e[0m\n"
    else
        printf "\e[31m\$file is not encrypted! Run 'make encrypt' and try again.\e[0m\n"
        exit 1
    fi
done
EOT
    
fi

chmod +x .git/hooks/pre-commit
