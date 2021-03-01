# cp4d-bigsql-ibm-cloud-roks

# Installing Cloud Pak for Data Cluster on IBM Cloud (ROKS) Openshift 4.5 Custom

## Installation of CP4D on IBM Managed Openshift Cluster with storage class ibmc-file-gold-gid (Non-airgapped method ie internet connected systems)

### Minimum required of Redhat Openshift cluster :
Each cluster must meet a set of minimum requirements: 3 nodes with 16 cores, 64GB memory, and 25GB disk per node.

### Installation phases:

- Pre-requisistes
- Pre-installation steps
- Preaparing the system for installation
- Installation
- Post-installation steps

**Pre-requisites:**

1)Provisioned single zone Redhat OpenShift Container cluster v 4.5 installed on IBM cloud

2)Redhat Openshift Container Webconsole

3)Cluster Admin Role

4)Install **_oc cli and cpd-cli_** in your local host from where you will be running the installation commands

5)Get the oc login credentials from the cluster

6)Configure Openshift to deploy CP4D

7)Create a **_oc project/namespace_** for deploying cp4d

8)Get the entitlement key for your entitled software library.
   
 - Log in to [Container software library](https://myibm.ibm.com/products-services/containerlibrary) on My IBM with the IBM ID and password that are associated with the entitled software.
 - On the Get entitlement key tab, select Copy key to copy the entitlement key to the clipboard.
 - Save the API key in a text file.

**Pre-instalaltion:**

This task must be completed by a Red Hat OpenShift cluster administrator. The administrator must have an access policy in IBM Cloud Identity and Access Management that has an Operator role or higher.

Changes applied

_The script makes the following changes to your Red Hat OpenShift cluster:_

- Increases the size of the Image registry volume to 200 GB. This change incurs cost to your account.
- Creates the security context constraints that are required for Cloud Pak for Data.
- Grants the security context constraints to the service accounts that are required for Cloud Pak for Data.

_Image registry permissions_

The instructions in this preinstallation script assume that your IBM Cloud user account is the same as your infrastructure account and you have permission to modify the storage in classic infrastructure. If this is not true, you must update the size for the Image registry volume from your infrastructure account.

You can either:

    Edit the settings of the volume that is bound to image-registry-storage pvc from the IBM Cloud console by going to Classic Infrastructure > Storage > File Storage.
    Manually run the commands in the following script to update the Image registry size from your infrastructure account.

If you are installing other applications in the cluster, or more Cloud Pak for Data services, you must increase the image registry space to more than 300GB.

1)Get the oc login credentials from the cluster and login to cluster

```
 oc login <openshift_console_url> --token <login_token>

 ibmcloud login --apikey <apikey_having_access_to_modify_volume>
```

**From GUI**
         IBM Cloud console -> Classic Infrastructure->Storage->File storage
         Identify the storage used for image registry and increase.
         
**From CLI**

Log in to the IBM Cloud command line interface and run the code snippet modifyVol.sh 

```
i)Download modifyVol.sh 
ii)chmod a+x modifyVol.sh
iii)./modifyVol.sh
```

2)Run the preinstallation script

If you are not a cluster administrator,  Copy the script and share it with your administrator.

Otherwise,  Run to run the following preinstallation script in the project that you specified in Configure your installation environment. It has the same effect regardless of the number of times it is run.

```
i)Download Preinstallation_script.sh
ii)chmod a+x Preinstallation_script.sh
iii)sh Preinstallation_script.sh
```

**NOTE:** The script will fail if you dont have necessary privileges like cluster admin and privilege to modify the storage (classic infrastructure permissions)

3)Create a docker image pull secret

In the project that you want to deploy your entitled containers, create an image pull secret so that you can access the cp.icr.io entitled registry. 

```
oc project kube-system

oc create secret docker-registry cpregistrysecret --docker-server=cp.icr.io/cp/cpd --docker-username=<username>  --docker-password=<password> --docker-email=<email>
```
  where 
-  --docker-username=cp
-  --docker-password = entitlement key
-  --docker-email=If you have one, enter your Docker email address. If you do not have one, enter a fictional email address, such as a@b.c. This email is required to create a Kubernetes secret, but is not used after creation
  
 4)Set the kernel parameters 
 
 - Download the deployment file setkernelparams.yaml
 - Execute the deployment file setkernelparams.yaml
 
 `oc apply -f setkernelparams.yaml -n kube-system`
 
 5)Give the service account privileged security context constraints (SCC) by running the following command:
 
 `oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:norootsquash`
 
 6)The File storage mounted as nfs v4. By default no root squash is not enabled.
 
 - Down the deployment file norootsquash.yaml
 - Execute the deployment file norootsquash.yaml
 
 `oc apply -f norootsquash.yaml -n kube-system`
 
 6)Create a route for docker registry
 ```
 oc create route reencrypt --service=image-registry -n openshift-image-registry
 oc annotate route image-registry --overwrite haproxy.router.openshift.io/balance=source -n openshift-image-registry
 ```

**Preaparing the system for installation:**

A Linux or Mac OS client workstation to run the installation from. The workstation does not have to be a node of the cluster, but must have internet access and be able to connect to the Red Hat® OpenShift® cluster.

1)Before you install Cloud Pak for Data, ensure that the installation files are available on your client system.

_Obtain the installation files:_

On the Linux or Mac OS workstation, download the appropriate file from cpd-cli GitHub:

[](url)https://github.com/IBM/cpd-cli

```
Edition 	                  TAR file
Enterprise Edition 	 cpd-cli-architecture-EE-version.tgz
Standard Edition 	    cpd-cli-architecture-SE-version.tgz
```

Download installer
```
wget https://github.com/IBM/cpd-cli/releases/download/v3.5.2/cpd-cli-linux-EE-3.5.2.tgz[](url) -P /tmp/
mkdir -p /cpd
tar xvf /tmp/cpd-cli-linux-EE-3.5.2.tgz -C /cpd
rm -f /tmp/cpd-cli-linux-EE-3.5.2.tgz
```

3)Set up the requirements for the cpd-cli command:

Edit the **repo.yaml** server definition file that you downloaded.
This file specifies the repositories for the cpd-cli command to download the installation files from. Make the following changes to the file:

_apikey_ =	Specify your entitlement license API key.

**Please make sure you leave a blank after the : ** 

The repository contains a sample repo.yaml file

**Installation:**

Installing Control Plane: (CP4D lite)

1)Login to your Redhat Openshift Cluster

`oc login --token=<obtained from Openshift Web Console> --server=<obtained from Openshift Web Console>`
  
2)Make sure you are in a directory where Installation tar is extracted

`cd /cpd/cpd-cli-linux-EE-3.5.2`

3)Set the below values in cli

```
REGISTRY=$(oc -n openshift-image-registry get route default-route -o custom-columns=HOST:.spec.host --no-headers=true)
PULL_PREFIX="image-registry.openshift-image-registry.svc:5000"
STORAGE_CLASS=ibmc-file-gold-gid
NAMESPACE=swapve29-cp4d-test
```

4)See what changes need to be made to the cluster, by running the appropriate cpd adm command for your environment:

`./cpd-cli adm --assembly lite --repo ./repo.yaml --namespace $NAMESPACE `

5)Apply changes to your cluster which you saw in above step

`./cpd-cli adm --assembly lite --repo ./repo.yaml --namespace $NAMESPACE --apply --accept-all-licenses`

6)Run the following command to install Control Plane
```
./cpd-cli install --assembly lite -n $NAMESPACE -c $STORAGE_CLASS --transfer-image-to=$REGISTRY/$NAMESPACE -r./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/$NAMESPACE --latest-dependency --accept-all-licenses
```
7)watch the installation process

`watch "oc get pods -n $NAMESPACE"`

8)To verify that the installation completed successfully, run the following command:
```
./cpd-cli status \
--assembly lite \
--namespace <namespace>
```
At the end of the installation, an URL will be printed which is a Cloud Pak for Data web console URL. You can verify it by logging in with admin/password

9)List available patches
```
cd /cpd/cpd-cli-linux-EE-3.5.2
./cpd-cli status -a lite -n <namespace> -r ./repo.yaml --patches --available-updates
```

10)Apply patch

Find the latest patch applicable to the Lite assembly and apply
```
PATCH_NAME="patch_name"

./cpd-cli patch -a lite -n swapve29-cp4d-test --patch-name $PATCH_NAME --transfer-image-to=$(oc registry info)/zen -r ./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen --ask-push-registry-credentials --action transfer --dry-run --insecure-skip-tls-verify
```

**NOTE:**
Either cluster admin can install or the project admin can install the control pane

**Run the following command to grant cpd-admin-role to the project administration user:**
```
oc adm policy add-role-to-user cpd-admin-role <project_admin> — role-namespace=<project-name> -n <project-name>

- project-admin : The user name of the project administrator who will install the Cloud Pak for Data control plane.

- project-name : Give any name where you will install Cloud Pak for Data Control Plane.
````

**Issues faced:**

1)This command returns error 

REGISTRY=$(oc -n openshift-image-registry get route default-route -o custom-columns=HOST:.spec.host --no-headers=true)

**_Error from server (NotFound): routes.route.openshift.io "default-route" not found_**

Follow these steps and then run the above REGISTRY= command again
```
Enable the image registry route:

1)Switch to the openshift-image-registry project

oc project openshift-image-registry

2)Create an internal registry route [one-time setup]

oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'

3)Acquire the image registry route in an env var for later use, and echo to ensure that it is set reasonably.

IMAGE_REGISTRY_ROUTE=$(oc get route | grep default-route | tr -s ' ' | cut -d' ' -f2)

echo $IMAGE_REGISTRY_ROUTE
```

2)If ./cpd-cli install command throws such kind of similar errors

**_[ERROR] [2021-02-28 19:15:39-0330] Unable to obtain the digest from the source docker://cp.icr.io/cp/cpd/swapve29-cp4d-test/influxdb:3.5.2-x86_64-97: Error resolving image source reference for docker://cp.icr.io/cp/cpd/swapve29-cp4d-test/influxdb:3.5.2-x86_64-97 - Error reading manifest 3.5.2-x86_64-97 in cp.icr.io/cp/cpd/swapve29-cp4d-test/influxdb: manifest unknown: manifest unknown_**

Then remove the **namespace** attribute from _repo.yaml_ and re-try





   


  
 



























