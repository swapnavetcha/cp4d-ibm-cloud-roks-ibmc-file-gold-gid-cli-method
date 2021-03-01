#!/bin/bash

JOB_NAMESPACE=<namespace>
JOB_CLUSTER_NAME=<clustername>

if [[ ${#JOB_NAMESPACE} -eq 0 ]] || [[ ${JOB_NAMESPACE} -gt 8 ]]; then
  echo "The project name cannot be empty or longer than 8 characters"
#else
#  echo "The project name  $JOB_NAMESPACE exists"
  exit 1
fi

if [[ ${JOB_NAMESPACE} == "default" ]] || [[ ${JOB_NAMESPACE} ==  "kube-"* ]] || [[ $JOB_NAMESPACE} == "openshift"* ]] || [[ $JOB_NAMESPACE} == "calico-"* ]] || [[ $JOB_NAMESPACE} == "ibm-"* ]] || [[ $JOB_NAMESPACE} == "tigera-operator" ]]; then
  echo "The project name cannot be default cluster namespaces"
  exit 1
fi

## Verify Ingress domain is created or not
for ((time=0;time<30;time++)); do
  oc get route -n openshift-ingress | grep 'router-default' > /dev/null 
  if [ $? == 0 ]; then
     break
  fi
  echo "Waiting up to 30 minutes for public Ingress subdomain to be created: $time minute(s) have passed."
  sleep 60
done

# Quits installation if Ingress public subdomain is still not set after 30 minutes
oc get route -n openshift-ingress | grep 'router-default'
if  [ $? != 0 ]; then
  echo -e "\e[1m Exiting installation as public Ingress subdomain is still not set after 30 minutes.\e[0m"
  exit 1
fi

##Identify the cluster type VPC or Classic
clusterType=""
oc get sc | awk '{print $2}' | grep "ibm.io/ibmc-file" > /dev/null
if [[ $? == 0 ]]; then
clusterType="classic"
fi

oc get sc | awk '{print $2}' | grep "vpc.block.csi.ibm.io" > /dev/null
if [[ $? == 0 ]]; then
clusterType="VPC"
fi

echo cluster is  $clusterType
zones=`ibmcloud ks cluster get -c $JOB_CLUSTER_NAME | grep "Worker Zones" | awk '{print $3 $4}'`
IFS=","
read -a zoneslist <<< "$zones"
if [[ ${#zoneslist[*]} > 1 ]]; then
echo "Cluster is Multi zone"
  if ! oc get sc | awk '{print $2}' | grep -q 'kubernetes.io/portworx-volume'; then
     echo -e "\e[1m Portworx storage is not configured on this cluster. Please configure portworx first and try installing \e[0m"
     exit 1
  fi
fi 

oc create sa cpdinstall -n kube-system
oc create sa cpdinstall -n ${JOB_NAMESPACE}


oc create -f - << EOF
allowHostDirVolumePlugin: false
allowHostIPC: true
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowedCapabilities:
- '*'
allowedFlexVolumes: null
apiVersion: security.openshift.io/v1
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups:
- cluster-admins
kind: SecurityContextConstraints
metadata:
  annotations:
    kubernetes.io/description: ${JOB_NAMESPACE}-zenuid provides all features of the restricted SCC but allows users to run with any UID and any GID.
  name: ${JOB_NAMESPACE}-zenuid
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities: null
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny  
users: []
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
EOF

oc adm policy add-scc-to-user ${JOB_NAMESPACE}-zenuid system:serviceaccount:${JOB_NAMESPACE}:cpdinstall
oc adm policy add-scc-to-user anyuid system:serviceaccount:${JOB_NAMESPACE}:icpd-anyuid-sa
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:${JOB_NAMESPACE}:cpdinstall
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:kube-system:cpdinstall

checkVolLimits() {

ibmcloud sl file volume-limits
if [[ $(ibmcloud sl file volume-limits | awk '$1 == "global" {print $2-$3}') -lt  50 ]]; then
echo -e "\e[1m The Storage volumes available on this account may not be sufficient to install all the supported services with IBM Cloud File Storage. Please make sure you have enough storage volumes to provision.\e[0m"
else
 echo "Sufficient File Storage volumes are available in the account"
fi

}

echo "SCRIPT EXECUTION COMPLETED"
