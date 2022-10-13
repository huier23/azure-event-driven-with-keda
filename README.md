# Event Driven Architecture for File processing
File upload -> Azure Blob -> trigger Azure Function (send msg to different service bus queue depends on file types) -> Service Bus Queue -> AKS (Keda trigger to process msg from queue)

## This terraform would provision the Azure resource as below:
- Azure Blob Storage
- Service Bus and three queue
- AKS with linux system agent pool and windows user agent pool
- Helm install Keda
- Azure Key Vault to store service bus secret
- Log analystics for AKS monitoring