#!/usr/bin/env bash
# sets up a pre-commit hook to ensure that vault.yml is encrypted
# https://github.com/ironicbadger/infra/blob/7acc044cd898a9c8471cd77810145c0aedebf68b/git-init.sh
#
# credit goes to nick busey from homelabos for this neat little trick
# https://gitlab.com/NickBusey/HomelabOS/-/issues/355

if [ -d ../.git/ ]; then
    rm ../.git/hooks/pre-commit
cat <<EOT >> ../.git/hooks/pre-commit
if ( git show :vars/vault.yml | grep -q "\$ANSIBLE_VAULT;" ); then
echo "[38;5;108mVault encrypted. Safe to commit.[0m"
else
    echo "[38;5;208mVault not encrypted! Run 'make encrypt' and try again.[0m"
exit 1
fi
EOT
    
fi

chmod +x ../.git/hooks/pre-commit
