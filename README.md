# icp-opa-test

- icpstate.rego contains OPA policies
- loadopa.sh loads the policies into OPA server and periodically loads data from Kuberentes and executes queries against the data
- Dockerfile builds image for OPA loader (download kubectl into the directory before building image)
- icp-opa-policy.yaml deploys a pod containing OPA server and data loader containers 
- To enable kubelet running container to access API server in ICP do the following command:

~~~
kubectl create clusterrolebinding add-on-cluster-admin  --clusterrole=cluster-admin --group=system:serviceaccounts
~~~
