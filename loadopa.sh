#!/bin/bash

# Run this as single pod in every ICP cluster with one container containing this bash script
# and another container holding the opa running in server mode i.e opa run -s

# Set the context so that kubectl will talk to the local K8S cluster
#kubectl config set-context $0

CLUSTERNAME="ibmcloud-tor-1"
MAXNODEIMAGESIZE="3e+10"
#KUBECONFIGFILE="/Users/khalida/.kube/config.sl.servicetoken"

# Can get the policy file from  external location (github/configmap)

# Load the policies 
curl -X PUT --data-binary @icpstate.rego  localhost:8181/v1/policies/icp


while true  
do
   rm -f nodes.json system-pods.json

   # Get data from K8S cluster and load into OPA server
   kubectl get nodes -o json > nodes.json 
   #kubectl --kubeconfig=$KUBECONFIGFILE get pods -n kube-system -o json > system-pods.json
   kubectl get pods -n kube-system -o json > system-pods.json

   curl -X PUT --data-binary @nodes.json localhost:8181/v1/data/nodes
   curl -X PUT --data-binary @system-pods.json localhost:8181/v1/data/syspods

   # Invoke each policy function and send an alert. We could have meta data associated with the policy which returns the
   # functions and the expected regexp for testing for a violation
   curl -s -X GET  localhost:8181/v1/data/icp/state/any_kubelets_not_matching_version | grep true 
   if [ $? -eq 0 ] 
   then
      # Send a curl request to post a notification to Slack or send to Prometheus at the master/management plane
      echo "Some kubelets dont match expected version"
      curl -s -X POST -H 'Content-type: application/json' --data '{"text":"Cluster: $"CLUSTERNAME" Nodes not matching K8S version"}'  $WEBHOOK 

       
   fi


   result=`curl -s -X GET  localhost:8181/v1/data/icp/state/sys_pods_not_ready`
   result2=`echo "${result//\"}"`
   echo $result2 | grep "\[\]"
   if [ $? -eq 1 ]
   then 
       echo "Some system pods are not in ready state"
       curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Cluster: "$CLUSTERNAME" Following system pods are not in ready state: "$result2" \"}"  $WEBHOOK
   fi

   curl -s -X GET  localhost:8181/v1/data/icp/state/any_nodes_not_ready | grep true
   if [ $? -eq 0 ] 
   then
       echo "Some nodes have conditions that require attention"
       curl -X POST -H 'Content-type: application/json' --data '{"text":"Cluster: "$CLUSTERNAME" Some nodes have conditions that require attention"}'  $WEBHOOK
   fi 

   inputdoc="{ \"input\": { \"maxsize\": "$MAXNODEIMAGESIZE" }}"
   echo $inputdoc
   result=`curl -s -X POST --data-binary "$inputdoc" localhost:8181/v1/data/icp/state/check_images_size`
   result2=`echo "${result//\"}"`
   echo $result2 | grep "\[\]"
   if [ $? -eq 1 ]
   then 
       echo "Some nodes have total image cache exceeding threshold"
       curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Cluster: "$CLUSTERNAME" Nodes having total image size exceeding threshold: "$result2" \"}"  $WEBHOOK
   fi
   sleep 60
done
