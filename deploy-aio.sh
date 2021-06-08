sudo apt update #
sudo apt -y install python3-pip python3-venv python3-dev
python3 -m venv $HOME/ansible
source $HOME/ansible/bin/activate
pip install wheel setuptools --upgrade
pip install ansible

cd $HOME/tf-os-ironic-aio
ansible-playbook playbooks/prepare-aio-host.yml
ansible-playbook playbooks/deploy_vbmc.yml

terraform init
terraform apply -auto-approve

ansible-playbook playbooks/prepare-aio.yml
ansible-playbook playbooks/set_bridge_forward_rules.yml
