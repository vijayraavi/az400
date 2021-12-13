#!/bin/sh
RESOURCE_GROUP=rg-k8s
LOGANALYTICS=logs-k8s
KUBERNETES=csk8s
APPINSIGHTS=k8sappinsights

# Install extensions
az extension add -n application-insights

# Create Resource Group
az group create -l eastus -n $RESOURCE_GROUP

# Create Log Analytics Workspace to store k8s and App Insights logs
az monitor log-analytics workspace create -g $RESOURCE_GROUP -n $LOGANALYTICS
WORKSPACEID=$(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $LOGANALYTICS --query "id" -o tsv)

# Create Azure Kubernetes Cluster with Log Analytics Workspace for Logging
az aks create --resource-group $RESOURCE_GROUP --name $KUBERNETES --node-count 1 --enable-addons monitoring --generate-ssh-keys --workspace-resource-id $WORKSPACEID

# Create App Insights to send logs from Container WebApp
az monitor app-insights component create --app $APPINSIGHTS --location eastus --kind web -g $RESOURCE_GROUP --workspace $WORKSPACEID
INSTRUMENTATION_KEY=$(az monitor app-insights component show --app $APPINSIGHTS -g $RESOURCE_GROUP --query "instrumentationKey" -o tsv)

# Connect to Kubernetes Cluster
az aks get-credentials --name $KUBERNETES -g $RESOURCE_GROUP --admin

# Create Secret with Application Gateway Instrumentation Key
kubectl create secret generic appinsightskey --from-literal=instrumentation-key=$INSTRUMENTATION_KEY

# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress