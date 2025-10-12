# ETL with Azure Data Factory - Private Network Integration

This project demonstrates an ETL solution using Azure Data Factory (ADF) with **private network integration** while maintaining **public endpoints** for flexibility.

## Architecture Overview

The solution includes:

### 🌐 **Virtual Network (VNet)**
- **Address Space**: `10.0.0.0/16`
- **Subnets**:
  - `adf-subnet` (`10.0.1.0/24`) - For ADF private endpoints
  - `sql-subnet` (`10.0.2.0/24`) - For SQL Server private endpoints  
  - `storage-subnet` (`10.0.3.0/24`) - For Storage Account private endpoints

### 🗄️ **Azure SQL Database**
- **Public Access**: Enabled (for management flexibility)
- **Private Endpoint**: Connected to `sql-subnet`
- **Private DNS Zone**: `privatelink.database.windows.net`
- **Firewall**: Azure services allowed via `0.0.0.0` rule

### 🏭 **Azure Data Factory**
- **Public Access**: Enabled (for management)
- **Private Endpoint**: Connected to `adf-subnet` for private access to ADF service
- **Private DNS Zone**: `privatelink.datafactory.azure.net`
- **Managed Virtual Network**: Configured for private connectivity to data sources
- **Managed Private Endpoints**: 
  - SQL Server private endpoint (outbound from ADF)
  - Storage Account private endpoint (outbound from ADF)
- **Integration Runtime**: AutoResolve with managed VNet
- **Linked Services**: Pre-configured for SQL and Storage with private connectivity

### 💾 **Storage Account (Data Lake Gen2)**
- **Public Access**: Enabled (with controlled access)
- **Private Endpoint**: Connected to `storage-subnet`
- **Private DNS Zone**: `privatelink.blob.core.windows.net`
- **Network ACLs**: Allow Azure services, default allow

## 🔐 **Security Features**

### **Dual Connectivity Model**
- **Private**: ADF connects to SQL and Storage via managed private endpoints
- **Public**: Management and external access still possible when needed

### **Network Isolation**
- All private endpoints deployed in dedicated subnets
- Private DNS zones ensure proper name resolution
- Network policies configured for security

### **Access Control**
- Storage Account: Public blob access disabled
- SQL Server: Azure services firewall rule enabled
- ADF: Managed identity for secure authentication

## 🚀 **Deployment**

1. **Prerequisites**:
   ```powershell
   # Install Azure CLI and Bicep
   az --version
   az bicep version
   ```

2. **Deploy the infrastructure**:
   ```powershell
   # Login to Azure
   az login

   # Deploy using Azure Developer CLI
   azd up
   
   # Or deploy using Azure CLI directly
   az deployment sub create `
     --location "East US" `
     --template-file "infra/main.bicep" `
     --parameters environmentName="myetl" sqlAdminPassword="YourSecurePassword123!"
   ```

## 📊 **Data Flow Architecture**

```
[Management/External Access]
       ↓ (Public Internet OR Private Endpoint)
[Azure Data Factory Service] 
       ↓ (Managed Private Endpoints via Managed VNet)
[Azure SQL Database] ←→ [Storage Account (Data Lake)]
       ↑ (All connected via Private Endpoints in VNet subnets)
[Virtual Network with Private DNS Zones]
```

### **Private Endpoint Coverage**
- **ADF Service**: Private endpoint in `adf-subnet` (for accessing ADF APIs privately)
- **ADF → SQL**: Managed private endpoint (for ADF to connect to SQL privately)
- **ADF → Storage**: Managed private endpoint (for ADF to connect to Storage privately)
- **Direct SQL Access**: Private endpoint in `sql-subnet` (for direct SQL management)
- **Direct Storage Access**: Private endpoint in `storage-subnet` (for direct Storage management)

## 🔧 **Benefits of This Architecture**

### **Security**
- Data movement happens over private network
- Reduced attack surface through private endpoints
- Network-level isolation for data services

### **Performance**  
- Private connectivity reduces latency
- No internet egress charges for data movement
- Dedicated bandwidth through private endpoints

### **Flexibility**
- Public endpoints maintained for management
- Hybrid connectivity options
- Easy integration with on-premises networks

### **Compliance**
- Network-level data isolation
- Private DNS resolution
- Controlled access patterns

## 🛠️ **Management Operations**

### **Connect to SQL Server**
```powershell
# Via public endpoint (if allowed by firewall)
sqlcmd -S "<sqlserver>.database.windows.net" -d salesdb -U sqladminuser -P

# Via private endpoint (from within VNet or connected network)
sqlcmd -S "<sqlserver>.database.windows.net" -d salesdb -U sqladminuser -P
```

### **Access Storage Account**
```powershell
# Via public endpoint
az storage blob list --account-name <storage> --container-name raw

# Via private endpoint (automatic when in VNet)
# Same commands work transparently
```

### **Monitor Private Endpoint Connections**
```powershell
# Check private endpoint status
az network private-endpoint show --name "<resource>-pe" --resource-group "rg-<environment>"

# Verify DNS resolution
nslookup <sqlserver>.database.windows.net
nslookup <storage>.blob.core.windows.net
```

## 📋 **Next Steps**

1. **Configure ADF Pipelines**: Create data pipelines using the pre-configured linked services
2. **Set up Monitoring**: Enable diagnostic settings and monitoring
3. **Security Hardening**: Implement additional firewall rules as needed
4. **Data Integration**: Upload sample data and test the ETL process

## 🔍 **Troubleshooting**

### **Private Endpoint Issues**
- Verify subnet configuration and network policies
- Check private DNS zone configuration
- Ensure proper virtual network links

### **Connectivity Problems**
- Test both private and public endpoint connectivity
- Verify firewall rules and network ACLs
- Check managed private endpoint approval status

### **ADF Connection Issues**
- Verify managed VNet configuration
- Check integration runtime status
- Test linked service connections