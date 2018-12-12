#!/bin/bash

while getopts g:i:e:p: option
do
case "${option}"
in
g) GUID=${OPTARG};;
i) INTERNAL=${OPTARG};;
e) EXTERNAL=${OPTARG};;
p) CURRENT_PATH=${OPTARG};;
esac
done


if [ -z $GUID ]; then GUID=`hostname|awk -F. '{print $2}'`; fi
if [ -z $INTERNAL ]; then INTERNAL=internal; fi
if [ -z $EXTERNAL ]; then EXTERNAL=example.opentlc.com; fi
if [ -z $CURRENT_PATH ]; then CURRENT_PATH=`pwd`; fi

echo -- GUID = $GUID --
echo -- Internal domain = $INTERNAL --
echo -- External domain = $EXTERNAL -- 
echo -- Current path = $CURRENT_PATH --


echo  "-- Preparing hosts file --"
cat ./config/templates/hosts.template | sed -e "s:{GUID}:$GUID:g;s:{DOMAIN_INTERNAL}:$INTERNAL:g;s:{DOMAIN_EXTERNAL}:$EXTERNAL:g;s:{PATH}:$CURRENT_PATH:g;" > hosts

echo -- Installing atomic packages --
yum -y install atomic-openshift-utils atomic-openshift-clients


echo -- Checking Openshift Prerequisites --
if ansible-playbook -f 20 -i ./hosts /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml ; then


    echo -- Prerequisites successful. Installing Openshift --
    ansible-playbook -f 20 -i ./hosts /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml


    echo -- Copying kube config --
    ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"
    oc login -u system:admin
    oc adm policy add-cluster-role-to-user cluster-admin admin


    echo -- Set up dedicated nodes --
    oc login -u system:admin
    oc label node node1.${GUID}.internal client=alpha
    oc label node node2.${GUID}.internal client=beta
    oc label node node3.${GUID}.internal client=common


    echo -- Creating user groups --
    oc adm groups new alphacorp andrew amy
    oc adm groups new betacorp brian betty
    oc adm groups new common


    echo -- Label user groups --
    oc label group alphacorp client=alpha
    oc label group betacorp client=beta
    oc label group common client=common


    echo -- Create project for Alpha Corp --
    oc new-project alphacorp
    oc label namespace alphacorp client=alpha
    oc adm policy add-role-to-group edit alphacorp -n alphacorp


    echo -- Create project for Beta Corp --
    oc new-project betacorp
    oc label namespace betacorp client=beta
    oc adm policy add-role-to-group edit betacorp -n betacorp


    echo -- Create project for common --
    oc new-project common
    oc label namespace common client=common
    oc adm policy add-role-to-group edit common -n common


    echo -- Creating nfs storage --
    ssh support1.${GUID}.internal "bash -s" -- < ./config/infra/create_pvs.sh
    rm -rf pvs; mkdir pvs
    
    for i in {1..50} 
    do
      cat ./config/templates/pvs/pv${i}.template | sed -e "s:{GUID}:$GUID:g" > ./pvs/pv${i}; 
    done


    cat ./pvs/* | oc create -f -


    echo -- Setting up CICD pipeline --
    sh ./scripts/provision.sh --user andrew deploy
    echo "Sleep for 5 minutes to allow the jenkins and CICD pipeline to be provisioned"
    sleep 5m


    echo -- Running pipeline --
    oc start-build tasks-pipeline -n tasks-build
    echo "Sleep for 15 minutes to allow the pipeline to finich and deploy "
    sleep 15m


    echo -- Set up autoscaler --
    oc project tasks-prod
    echo '{
        "kind": "LimitRange",
        "apiVersion": "v1",
        "metadata": {
            "name": "tasks-hpa",
            "creationTimestamp": null
        },
        "spec": {
            "limits": [
                {
                    "type": "Pod",
                    "max": {
                        "cpu": "2",
                        "memory": "4Gi"
                    },
                    "min": {
                        "cpu": "100m",
                        "memory": "512Mi"
                    }
                },
                {
                    "type": "Container",
                    "max": {
                        "cpu": "2",
                        "memory": "4Gi"
                    },
                    "min": {
                        "cpu": "100m",
                        "memory": "512Mi"
                    },
                    "default": {
                        "cpu": "300m",
                        "memory": "2Gi"
                    },
                    "defaultRequest": {
                        "cpu": "100m",
                        "memory": "512Mi"
                    }
                }
            ]
        }
    }' | oc create -f - -n tasks-prod

    oc set resources dc/tasks --requests=cpu=100m -n tasks-prod

    oc autoscale dc/tasks --min 1 --max 5 --cpu-percent=80 -n tasks-prod

else
    echo -- Prerequisites failed --
fi