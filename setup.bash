#!/usr/bin/env bash

set -e

LOCATION=westus
RESOURCE_GROUP=SYNIVERSE-RG
AKS_CLUSTER=SYNIVERSE-SPOT-POOL-CLUSTER
MC_RESOURCE_GROUP=MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_${LOCATION}
SPOT_VMSS_TYPE=spotnodepool
VM_TYPE=Standard_A2_v2

ssh-keygen -f "$(echo "$AKS_CLUSTER" |  awk '{print tolower($0)}' | tr '-' '_')" -t rsa -b 4096 -C "$AKS_CLUSTER" -q -N ""

az account set --subscription $SUBSCRIPTION

az feature register \
  --subscription $SUBSCRIPTION \
  --namespace "Microsoft.ContainerService" --name "spotpoolpreview"

az feature list -o table \
  --subscription $SUBSCRIPTION \
  --query "[?contains(name, 'Microsoft.ContainerService/spotpoolpreview')].{Name:name,State:properties.state}"

az provider register \
	--subscription $SUBSCRIPTION \
	--namespace Microsoft.ContainerService

az group create --name $RESOURCE_GROUP --subscription $SUBSCRIPTION --location $LOCATION

az aks create \
	--subscription $SUBSCRIPTION \
    	--resource-group $RESOURCE_GROUP  \
    	--name $AKS_CLUSTER \
    	--vm-set-type VirtualMachineScaleSets \
    	--node-count 1 \
    	--ssh-key-value "$(echo "$AKS_CLUSTER" |  awk '{print tolower($0)}' | tr '-' '_')".pub\
    	--load-balancer-sku standard \
    	--enable-cluster-autoscaler \
    	--min-count 1 \
    --max-count 3


az aks get-credentials \
	--subscription $SUBSCRIPTION \
	--resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER

az aks nodepool add \
	--subscription $SUBSCRIPTION \
    	--resource-group $RESOURCE_GROUP \
    	--cluster-name $AKS_CLUSTER \
    	--name $SPOT_VMSS_TYPE\
    	--priority Spot \
    	--spot-max-price -1 \
    	--eviction-policy Delete \
    	--node-vm-size $VM_TYPE \
    	--node-count 2 \
    	--node-osdisk-size 32 \
    	--enable-cluster-autoscaler \
    	--min-count 2 \
    	--max-count 6

NODE_VMSS=$(az vmss list --resource-group $MC_RESOURCE_GROUP --subscription $SUBSCRIPTION --query '[0].name' -otsv)

az vmss scale \
	--subscription $SUBSCRIPTION \
	--resource-group $MC_RESOURCE_GROUP \
	--name $NODE_VMSS \
	--new-capacity 0

#K8S_IP_ID=$(az network public-ip list \
#	--subscription $SUBSCRIPTION \
#	--resource-group $MC_RESOURCE_GROUP \
#    	--query '[1].id' -otsv)


#az network public-ip update --ids $K8S_IP_ID --dns-name syniverse-poc

#az group delete \
#	--subscription $SUBSCRIPTION \
#   	--name $RESOURCE_GROUP \
#    	--yes --no-wait
