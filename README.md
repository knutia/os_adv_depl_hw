# os_adv_depl_hw

Quick Start

With the assumption that the infrastructure layer has been set up and configured according openshift system requirements, the installation can be invoked by following the steps below:

1.	Login to Bastion Host using Putty using credentials (key).

    Host: - bastion.$GUID.example.opentlc.com

2.	Change to root user
    sudo –i

3.	Clone the playbooks

    cd $HOME
    
    git clone https://github.com/knutia/os_adv_depl_hw.git

4.	Execute below commands to start installation :

	cd os_adv_depl_hw
	./install.sh
