
# LogScale Cluster Deployment Automated Using PowerShell in Azure AKS

## Overview :

This script  provision a self-hosted LogScale cluster on Azure Cloud using Azure Kubernetes Services (AKS), with Azure object store for event repositories. This script is completely automated using Power Shell.
This script follows the same pattern as described in the [CrowdStrike/logscale-azure-aks-deployment](https://github.com/CrowdStrike/logscale-azure-aks-deployment) Github repo.

Notes:

- This cluster deployment utilizes an independent Kafka service.
- This document assumes at least intermediate level knowledge of Azure Cloud.

## Architectural Diagrams:

**Deployment Overview:**

![dep-overview](/docs/asset/dep-overview.png)

**Functional Overview:**

![fun-overview](/docs/asset/fun-overview.png)

## Prerequisites :
- Azure Portal account with an active subscription
- Azure Storage account
- Good understanding of Kubernetes

- Falcon LogScale License Key
  - The key should be installed in "scretkey" file in the same folder where powershell script "aks-cluster-setup.ps1" is placed
  - aks-cluster-setup.ps1 script has all the variables that can be changed as per the guideline described in logscale-azure-aks-deployment  README.md file.


## Steps to Set Up:

Download the "src" folder from the repository
### Note:

    Please go through the following important points--
         1. Please change the variable values in the powershell as per targeted environment
         2. Please prepare a file called "secretkey" and place targeted environment logscale cluster key without any space or any other special character
         3. The Powershell script should be place in the same directory as "secretkey" file
         4. After running the power shell script, following yaml files will be place the current directory:
                 a. kafka-zookeeper.yaml
                 b. s3Proxy-service.yaml
                 c. s3Proxy.yaml
                 d. humiocluster.yaml
                 e. ingress.yaml
         5. If the script re-ran then above all yaml files will be overwritten


In order to do the set up either create a separate Folder of your choice or can place the below files in the root folder

- Upload "aks-cluster-setup.ps1" in Azure Cloud Shell
- Upload "secretkey" file and replace the appropriate logscale license (make sure no additional characters or space is appeneded)
- Optional Upload "ingress_test.yaml" (this file is used for testing ingress after the set up is completed)
- Once everything is uploaded please run the following command

#### Commands To Run:
    -  pwsh ./aks-cluster-setup.ps1 (If powershell is place in a folder please cd <folder_name>)
    -  kubectl apply -f ingress_test.yaml (optional)



## Expected Infrastructure After Set Up
The powershell setup script will create

    - Azure Resource Group
    - Azure Kubernetes Cluster (AKS)
    - Azure Storage Account for humio cluster blob container to save excess data
    - Logscale Container
    - Spinning Up Kafka, Zookeeper using Strimzi
    - s3Proxy Services for connecting Azure Storage with logscale cluster
    - Prepare Logscale-Operator using Helm
    - Logscale Cluster to ingest data
    - Deploy Application gateway and enable AGIC

## View Running Pods, Services In AKS

    View pods:
    > Kubectl get pods

    View service:
    > Kubectl get svc

    View ingress (Public IP):
    > Kubectl get ingress






## Clean Up Resources

To clean the above installed set up please use the aks-cluster-delete.ps1 powershell script

### Note
    Make sure the delete powershell script has same names as used in the set up powershell script.

### Command To Run:
    pwsh ./aks-cluster-delete.ps1



**Useful Reference Links:**
  - [LogScale K8s Reference Architecture](https://library.humio.com/falcon-logscale-self-hosted/installation-k8s-ref-arch.html)
  - [K8s core concept for AKS](https://learn.microsoft.com/en-us/azure/aks/concepts-clusters-workloads)

<p align="center"><img src="docs/asset/cs-logo-footer.png"><BR/><img width="150px" src="docs/asset/adversary-red-eyes.png"></P>
<h3><P align="center">WE STOP BREACHES</P></h3>
~
