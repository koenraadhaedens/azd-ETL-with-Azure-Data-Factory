# SQL Server Firewall Security Configuration

This project has been updated to comply with security policies that prohibit the use of `0.0.0.0/0` firewall rules for SQL Server.

## Security Options

### Option 1: Specific IP Ranges (Current Implementation)
The current configuration uses specific Azure Data Factory Integration Runtime IP ranges instead of the broad `0.0.0.0` rule.

**Files modified:**
- `infra/modules/sql.bicep`
- `infra/modules/sql-with-aad.bicep` 
- `infra/main.bicep`

**Configuration:**
The `dataFactoryIPRanges` parameter in `main.bicep` contains region-specific IP ranges for Azure Data Factory. You must update these ranges based on your deployment region.

**How to get the correct IP ranges:**
1. Visit the Azure Data Factory documentation: https://docs.microsoft.com/en-us/azure/data-factory/data-movement-security-considerations#azure-ir-ip-addresses
2. Find the IP ranges for your specific Azure region
3. Update the `dataFactoryIPRanges` parameter in `main.bicep`

**Example for different regions:**
```bicep
// East US
param dataFactoryIPRanges array = [
  { start: '20.42.2.0', end: '20.42.2.255' }
  { start: '20.42.4.0', end: '20.42.4.255' }
  { start: '20.42.5.0', end: '20.42.5.255' }
  { start: '40.71.14.32', end: '40.71.14.63' }
]

// West US 2
param dataFactoryIPRanges array = [
  { start: '20.42.130.0', end: '20.42.130.255' }
  { start: '20.42.132.0', end: '20.42.132.255' }
  { start: '40.78.242.96', end: '40.78.242.127' }
]
```

### Option 2: Private Endpoints (Most Secure - Optional)
For maximum security, consider using the private endpoint configuration provided in `sql-private-endpoint.bicep`. This approach:
- Disables public network access to SQL Server
- Uses Azure Private Link for secure connectivity
- Requires Virtual Network configuration
- Provides network-level isolation

**To use private endpoints:**
1. Deploy a Virtual Network and subnet for private endpoints
2. Replace the SQL module reference in `main.bicep` with `sql-private-endpoint.bicep`
3. Provide the required VNet and subnet parameters

## Deployment

### Using Specific IP Ranges (Recommended for simplicity)
```bash
# Update the IP ranges in main.bicep first, then deploy
azd deploy
```

### Using Private Endpoints (Recommended for maximum security)
1. First deploy a VNet infrastructure
2. Update `main.bicep` to use `sql-private-endpoint.bicep`
3. Deploy with VNet parameters

## Compliance Notes
- ✅ No longer uses `0.0.0.0/0` firewall rules
- ✅ Restricts access to specific Azure Data Factory IP ranges
- ✅ Maintains functionality for ETL operations
- ✅ Provides option for private endpoint connectivity

## Troubleshooting
If Azure Data Factory cannot connect to SQL Database after deployment:
1. Verify the IP ranges match your deployment region
2. Check Azure Data Factory Integration Runtime location
3. Ensure the IP ranges are current (Microsoft updates these periodically)
4. Consider using Private Endpoints for better security and reliability