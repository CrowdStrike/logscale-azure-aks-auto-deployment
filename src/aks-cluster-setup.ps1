
<#
Description: This powershell suffice the following requirements (please visit note section before proceeding) :
  
  1. Creates Azure Resource Group
  2. Creates Azure Kubernetes Cluster (AKS)
  3. Creates Azure Storage Account for humio cluster blob container to save excess data
  4. Creates Humio Container
  5. Spinning Up Kafka, Zookeeper using Strimzi
  6. Creates s3Proxy Services for connecting Azure Storage with humio cluster
  7. Prepare Humio-Operator using Helm
  8. Finally Creates Humio Cluster to ingest data


Note: 
  
  Please go through the following important points--
  1. Please change the variable values as per targeted environment
  2. Please prepare a file called "secretkey" and place targeted environment humiocluster key without any space or any other special character
  3. This Powershell script should be place in the same directory as "secretkey" file
  4. After running this power shell script, following yaml files will be place the current directory:
    a. kafka-zookeeper.yaml
    b. s3Proxy-service.yaml
    c. s3Proxy.yaml
    d. humiocluster.yaml
  5. If this script re-ran then above all yaml files will be overwritten
#>

####################################################################################################################################################################

# Variables List

$AKS_RG="rg-aks-cluster"                                    # Resource Group Name
$AKS_NAME="aks-cluster-test"                                # Azure Kubernetes Service Name
$STORAGE_ACCOUNT_NAME="saakstestimran01"                    # Storage Account Name
$HUMIO_CLUSTER_NAME = "example-humiocluster"                # HumioCluster Name  
$ZOEEKPER_CONTAINER_NAME="zookeeper-container-01"           # Zookeeper Container Name
$KAFKA_CONTAINER_NAME="kafka-container-01"                  # Kafka Container Name
$HUMIO_CONTAINER_NAME="humio-container-01"                  # Kafka Container Name
$IDENTITY_NAME="identity-mgmt-account"                      # Managed Identity Name
$AKS_NODE_COUNT = 2                                         # Number of Nodes in AKS
$LOCATION = "East US 2"                                     # Region Name
$ZOOKEEPER_BLOB_STORAGE = "100Gi"                           # Zookeeper BlobFuse Storage Capacity
$KAFKA_BLOB_STORAGE = "500Gi"                               # Kakfa BlobFuse Storage Capacity
$ZOOKEEPER_DISK_STORAGE = "25Gi"                            # Zookeeper Disk Storage Capacity
$KAFKA_DISK_STORAGE = "50Gi"                                # Kakfa Disk Storage Capacity
$ENVIRONMENT = "test"                                       # Enrionment Name
$HUMIO_AUTHENTICATION_METHOD ="single-user"                 # Authentication Method to get into Logscale
$HUMIO_PASSWORD = "MyPassword01"                            # Logscale Password
$HUMIO_CLUSTER_NAME ="example-humiocluster"                 # Logscale Cluster Name
$HUMIO_CLUSTER_REPLICATION = 3                              # Logscale Replication Factor
$HUMIO_NODE_COUNT = 3                                       # LogScale Node Count 
$HUMIO_STORAGE_CAPACITY = "10Gi"                            # LogScale Internal Storage Capacity
$HUMIO_STORAGE_CLASSNAME = "managed-csi"                    # Storage Class Name for creating Internal Storage Capacity   
$PVC_YAML = "pvc-blobfuse.yaml"                             # Persistent Volume Claim Yaml File Name
$PV_YAML = "pv-blobfuse.yaml"                               # Persistent Volume Yaml File Name
$KAFKA_ZOOKEEPER_YAML = "kafka-zookeeper.yaml"              # Kafka Zookeeper Yaml File Name
$HUMIOCLUSTER_YAML = "humiocluster.yaml"                    # HumioCluster Yaml File Name
$S3PROXY_SERVICE_YAML = "s3Proxy-service.yaml"              # s3Proxy Service Yaml File Name  
$S3PROXY_YAML = "s3Proxy.yaml"                              # s3Proxy Yaml File Name  
$HUMIO_SECRET_KEY_NAME = "example-humiocluster-license"     # Humio Secret Key for Humio Cluster   
$KAFKA_ZOOKEEPER_REPLICATION = 3                            # Zookeeper Kafka Replication Factor
$KAFKA_CLUSTER_NAME = "my-cluster"                          # KAFKA Cluster Name
$HUMIO_OPERATOR_VERSION = "0.19.0"                          # Humio Operator Version
$AKS_VM_MACHINE = "Standard_DS2_v2"                         # AKS VM Machine Size
$AKS_VERSION = "1.25.6"                                     # AKS Version
$JCLOUDS_PROVIDER = "azureblob"                             # Jcloud Provider
$AZURE_CONTAINER_ENDPOINT=""                                # Azure Storage Conainer(Blob) EndPoint
$AZURE_STORAGE_SAS_TOKEN = ""                               # Azure Storage Account SAS Token
$JCLOUDS_AZUREBLOB_AUTH = "azureKey"                        # Azure AUTH
$LOG_LEVEL = "debug"                                        # Log Level (debug,info,warning,error,critical)
$KAKFA_COUNTER_LIMIT = 15                                   # Kafka Counter to check the status Kafka Running Pods
$VNET_NAME = "aks-vnet-test"                                # Vnet name for AKS and App Gateway
$VNET_CIDR = "10.224.0.0/12"                                # Vnet CIDR
$AKS_SUBNET ="aks-subnet"                                   # Aks subnet name
$AKS_SUBNET_CIDR = "10.224.0.0/16"                          # Aks subnet CIDR
$APP_GATEWAY ="appgw-test"                                  # App gateway for ingress
$APP_GATEWAY_SUBNET ="appgw-subnet"                         # Subnet for App Gateway
$APP_GATEWAY_SUBNET_CIDR = "10.225.1.0/24"                  # Subnet CIDR For App Gateway
$PUBLIC_IP = "publicip-test"                                # Public Ip for Ingress


# Create resource group and connect to AKS cluster (open this below commented line if new resource group is needed)
echo "`n ===========   Resource Group Creating   ==========="
az group create --name $AKS_RG --location $LOCATION

Write-Host "`n ===========   Vnet and Subnet Creating   =========== "
az network vnet create --resource-group $AKS_RG --name $VNET_NAME --address-prefixes $VNET_CIDR --subnet-name $AKS_SUBNET --subnet-prefixes $AKS_SUBNET_CIDR
az network vnet subnet create -g $AKS_RG --vnet-name $VNET_NAME -n $APP_GATEWAY_SUBNET --address-prefix $APP_GATEWAY_SUBNET_CIDR

$vnetStatus = (az network vnet show --resource-group $AKS_RG --name $VNET_NAME --query 'provisioningState' --output tsv)
if ($vnetStatus -ne "Succeeded")
{
  Write-Host "Vnet Creation Failed!!! Existing the Script"
  Exit

}
#Extract $AKS_SUBNET and $APP_GATEWAY_SUBNET id
$aks_subnet_id = $(az network vnet subnet show --name $AKS_SUBNET --vnet-name $VNET_NAME -g $AKS_RG --query 'id' --output tsv)
$appgw_subnet_id = $(az network vnet subnet show --name $APP_GATEWAY_SUBNET --vnet-name $VNET_NAME -g $AKS_RG --query 'id' --output tsv)

# Creating AKS Cluster
echo "`n ===========   Azure Kubernetes Service (AKS) Cluster Creating (Please Be Patient, This will take few minutes to complete)   ==========="
az aks create --name $AKS_NAME --resource-group $AKS_RG --node-count $AKS_NODE_COUNT --node-vm-size $AKS_VM_MACHINE --zones 1 2 3 --kubernetes-version $AKS_VERSION  --network-plugin azure  --enable-blob-driver --vnet-subnet-id $aks_subnet_id

# Wait for cluster creation to complete

Write-Host "... Waiting for AKS cluster to complete ..."
$clusterStatus = " "

#while ($clsuterStatus -ne "Succeeded")
#{
  $clusterStatus = (az aks show --resource-group $AKS_RG --name $AKS_NAME --query 'provisioningState' --output tsv)
  #Write-Host $clusterStatus
  #Start-Sleep -Seconds 10
#}
if ($clusterStatus -ne "Succeeded")
{
  Write-Host "AKS Cluster Creation Failed!!! Existing the Script"
  Exit

}

Write-Host "AKS cluster creation completed successfully!!!"

# Connecting to AKS Cluster created above
echo "`n ===========   Connecting to the AKS Cluster   ==========="
az aks get-credentials -n $AKS_NAME -g $AKS_RG --overwrite-existing

# Fetching Nodes
echo "`n ===========   Getting the Current Nodes of AKS   ==========="
kubectl get nodes

#Creating Public IP
Write-Host "`n ===========   Public IP Creating   =========== "
az network public-ip create --resource-group $AKS_RG --name $PUBLIC_IP --sku Standard --allocation-method Static
$public_ip_address =$(az network public-ip show --name $PUBLIC_IP -g $AKS_RG --query 'ipAddress' -o tsv)

Write-Host "`n Public IP Address to be used as Ingress from outside is : $public_ip_address"
#Creating App Gateway for Ingress
Write-Host "`n ===========   Azure App Gateway Creating (this can take up few minutes to complete)   =========== "
#extracting vnet id
$vnet_id=$(az network vnet list --resource-group $AKS_RG --query "[0].id" --output tsv)  
az network application-gateway create --name $APP_GATEWAY --resource-group $AKS_RG --location $LOCATION --sku Standard_V2 --http-settings-cookie-based-affinity Disabled --public-ip-address $PUBLIC_IP --vnet-name $vnet_id --subnet $appgw_subnet_id --http-settings-protocol Http --http-settings-port 80 --priority 1000 

#Extract AppGateway Id and Attach it to AKS Cluster
Write-Host "`n ===========   Adding $APP_GATEWAY App Gateway to the $AKS_NAME AKS Cluster (this can take up few minutes to complete)   =========== "
$app_gateway_id=$(az network application-gateway show --name $APP_GATEWAY -g $AKS_RG --query 'id' --output tsv)
az aks enable-addons -g $AKS_RG --name $AKS_NAME --addons ingress-appgw --appgw-id $app_gateway_id

# Verify the blob driver (DaemonSet) was installed

#Set-Alias -Name grep -Value select-string # if using powershell
#kubectl get pods -n kube-system | grep csi

# Create Storage Account
echo "`n ===========   Storage Account and Container Creating   ==========="
az storage account create -n $STORAGE_ACCOUNT_NAME -g $AKS_RG -l $LOCATION --sku Premium_ZRS --kind BlockBlobStorage

# Create a zookeeper container
#az storage container create --account-name $STORAGE_ACCOUNT_NAME -n $ZOEEKPER_CONTAINER_NAME

# Create a kafka container
#az storage container create --account-name $STORAGE_ACCOUNT_NAME -n $KAFKA_CONTAINER_NAME

# Create a humio container
az storage container create --account-name $STORAGE_ACCOUNT_NAME -n $HUMIO_CONTAINER_NAME


##########################################################################################################################
# extract Storage Account's Container Endpoint

$AZURE_CONTAINER_ENDPOINT = az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $AKS_RG --query "primaryEndpoints.blob" --output tsv
$AZURE_CONTAINER_ENDPOINT = "$AZURE_CONTAINER_ENDPOINT$HUMIO_CONTAINER_NAME"
 
# extract Storage Account SAS Token
$AZURE_STORAGE_SAS_TOKEN = az storage account keys list --account-name saaksblobfusetest --resource-group AKS-imran-logscale-test --query "[0].value" --output tsv

echo "`n ===========   Setting up Strimzi   ==========="
#installing helm chart for strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install strimzi-kafka strimzi/strimzi-kafka-operator

#verify strimzi
kubectl get pods
kubectl get crd | grep strimzi

echo "`n ===========   Setting up KAFKA and ZOOKEEPER   ==========="

@"
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: $KAFKA_CLUSTER_NAME
spec:
  kafka:
    version: 3.4.0
    replicas: $KAFKA_ZOOKEEPER_REPLICATION 
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      inter.broker.protocol.version: "3.4"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: $KAFKA_DISK_STORAGE 
        deleteClaim: false
  zookeeper:
    replicas: $KAFKA_ZOOKEEPER_REPLICATION
    storage:
      type: persistent-claim
      size: $ZOOKEEPER_DISK_STORAGE
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
"@ > $KAFKA_ZOOKEEPER_YAML

kubectl apply -f $KAFKA_ZOOKEEPER_YAML

# Checking The Kakfa installation by running the loop for kakfka pod status. This loop exit Either if the kafka pod is up and running Or Kafka Check Counter is Exhausted


Write-Host "`e[1mKafka Installation Check Begins and will last for $KAKFA_COUNTER_LIMIT number of checks if Kafka is not up `e[0m" -ForegroundColor DarkMagenta
$isKafkaRunning = $false 
$kafkaPodName = "$KAFKA_CLUSTER_NAME-kafka-0"
$counter = 0
while ((-not $isKafkaRunning) -and ($counter -lt $KAKFA_COUNTER_LIMIT)) {

$podStatus =  $(kubectl get pods -o json | jq -r ".items[] | select(.metadata.name ==""$kafkaPodName"") | .status.phase")
Write-Host "PodStatus - $podStatus and counter is $counter"

 if ($podStatus -eq "Running")

  {
    $isKafkaRunning = $true 
    break
  }
  
  $counter++
  Start-Sleep -Seconds 15

}

if ($isKafkaRunning){
  Write-Host "Kafka is Installed Successfully" -ForegroundColor Green
}
else{
    Write-Host "Kafka Check Counter is Exhausted but Kakfa may be installed in some time. Please check again once the whole set up is completed" -ForegroundColor Yellow
}
echo "`n ===========   Setting up s3Proxy   ==========="

#s3Proxy Yaml
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: s3proxy
  template:
    metadata:
      labels:
        app: s3proxy
    spec:
      containers:
      - name: s3proxy
        image: andrewgaul/s3proxy:latest
        ports:
          - containerPort: 80
        env:
          - name: S3PROXY_AUTHORIZATION
            value: "none"
          - name: JCLOUDS_PROVIDER
            value: $JCLOUDS_PROVIDER
          - name: JCLOUDS_ENDPOINT
            value: $AZURE_CONTAINER_ENDPOINT
          - name: JCLOUDS_IDENTITY
            value: $STORAGE_ACCOUNT_NAME
          - name: JCLOUDS_CREDENTIAL
            value: $AZURE_STORAGE_SAS_TOKEN
          - name: JCLOUDS_AZYREBLOB_AUTH
            value: $JCLOUDS_AZUREBLOB_AUTH
          - name: LOG_LEVEL
            value: $LOG_LEVEL
          

"@ > $S3PROXY_YAML

kubectl apply -f $S3PROXY_YAML

echo "`n ===========   Setting up s3Proxy-Service   ==========="

#s3Proxy-Service Yaml
@"
apiVersion: v1
kind: Service
metadata:
  name: s3proxy
spec:
  selector:
    app: s3proxy
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
"@ > $S3PROXY_SERVICE_YAML

kubectl apply -f $S3PROXY_SERVICE_YAML

echo "`n ===========   Setting up Logscale (Humio) Operator   ==========="


# Install Humio Operator

kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioclusters.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioexternalclusters.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioingesttokens.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioparsers.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humiorepositories.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioviews.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioalerts.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/humio/humio-operator/humio-operator-${HUMIO_OPERATOR_VERSION}/config/crd/bases/core.humio.com_humioactions.yaml

helm repo add humio-operator https://humio.github.io/humio-operator
helm install humio-operator humio-operator/humio-operator --version="${HUMIO_OPERATOR_VERSION}" --skip-crds


echo "`n ===========   Setting up SecretKey and Logscale (Humio) Cluster   ==========="
 # Create the Secret Key for Logscale Cluster (Use secretkey file which contains Logscale key)

  $logscalekey = Get-Content -Path "./secretkey"
  kubectl create secret generic $HUMIO_SECRET_KEY_NAME --from-literal=data=$logscalekey

@"
apiVersion: core.humio.com/v1alpha1
kind: HumioCluster
metadata:
  name: $HUMIO_CLUSTER_NAME
spec:
  # select latest/stable image 
  image: "humio/humio-core:1.88.0"
  nodeCount: $HUMIO_NODE_COUNT
  license:
    secretKeyRef:
       # Secret must be created with the following command: kubectl create secret generic example-humiocluster-license --from-literal=data=<license>
      name: $HUMIO_SECRET_KEY_NAME
      key: data
  tls:
    enabled: false
  targetReplicationFactor: $HUMIO_CLUSTER_REPLICATION
  storagePartitionsCount: 24
  digestPartitionsCount: 24
   
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: humio_node_type
            operator: In
            values:
            - core
        - matchExpressions:
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - humio-core
        topologyKey: kubernetes.io/hostname

  dataVolumePersistentVolumeClaimSpecTemplate:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: $HUMIO_STORAGE_CAPACITY
    storageClassName: $HUMIO_STORAGE_CLASSNAME

  environmentVariables:
    - name: "AUTHENTICATION_METHOD"
      value: $HUMIO_AUTHENTICATION_METHOD
    - name: "SINGLE_USER_PASSWORD"
      value: $HUMIO_PASSWORD
    - name: "KAFKA_SERVERS"
      value: "my-cluster-kafka-bootstrap:9092"
    - name: PUBLIC_URL
      value: https://example-humiocluster.logscale.local
    - name: USING_EPHEMERAL_DISKS
      value: "true"
    - name: S3_STORAGE_ENDPOINT_BASE
      value: http://s3proxy
    - name: S3_STORAGE_ACCESSKEY
      value: $AZURE_STORAGE_SAS_TOKEN
    - name: S3_STORAGE_SECRETKEY
      value: $AZURE_STORAGE_SAS_TOKEN
    - name: LOCAL_STORAGE_PERCENTAGE
      value: "80"
    - name: S3_STORAGE_PATH_STYLE_ACCESS
      value: "true"
    - name: S3_STORAGE_IBM_COMPAT
      value: "true"
    - name:  BUCKET_STORAGE_IGNORE_ETAG_UPLOAD 
      value: "true"
    - name:  BUCKET_STORAGE_IGNORE_ETAG_AFTER_UPLOAD 
      value: "false"
    - name: BUCKET_STORAGE_SSE_COMPATIBLE
      value: "true"
    - name: S3_STORAGE_ENCRYPTION_KEY
      value: "off"
    - name: S3_STORAGE_BUCKET
      value: $HUMIO_CONTAINER_NAME
    - name: S3_ARCHIVING_PATH_STYLE_ACCESS
      value: "true"
    - name: S3_EXPORT_PATH_STYLE_ACCESS
      value: "true"
    - name: S3_STORAGE_PREFERRED_COPY_SOURCE
      value: "true"

"@ > $HUMIOCLUSTER_YAML

  kubectl apply -f $HUMIOCLUSTER_YAML
  

kubectl get pods,svc,pvc,pv

Write-Host "`n `e[1m===========   Congratulations!!! LogScale Cluster Successfully Installed on AKS, Happy LogScaling   =========== `e[0m" -Foreground Green
