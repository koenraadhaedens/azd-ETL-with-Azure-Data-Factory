param sqlServerName string
param databaseName string
param location string
param adfPrincipalId string
param dataFactoryName string
@secure()
param sqlAdminPassword string

// Create SQL user for ADF managed identity and assign roles
resource createAadUserDeployment 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'create-aad-sql-user-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azCliVersion: '2.50.0'
    scriptContent: '''
#!/bin/bash

# Install sqlcmd
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install -y mssql-tools unixodbc-dev

# Add to PATH
export PATH="$PATH:/opt/mssql-tools/bin"

# Connection parameters
SERVER="${SQL_SERVER_NAME}.database.windows.net"
DATABASE="${DATABASE_NAME}"
USERNAME="${SQL_ADMIN_USER}"
PASSWORD="${SQL_ADMIN_PASSWORD}"
ADF_NAME="${DATA_FACTORY_NAME}"

echo "Creating AAD user for Data Factory managed identity..."

# Create SQL script to add AAD user and assign roles
cat << EOF > create_aad_user.sql
-- Create user for Azure Data Factory managed identity
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${ADF_NAME}')
BEGIN
    CREATE USER [${ADF_NAME}] FROM EXTERNAL PROVIDER;
    PRINT 'Created user for Data Factory managed identity'
END
ELSE
BEGIN
    PRINT 'User for Data Factory managed identity already exists'
END

-- Assign necessary roles for ETL operations
-- db_datareader: Read data from tables
IF NOT IS_ROLEMEMBER('db_datareader', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_datareader role'
END

-- db_datawriter: Write data to tables
IF NOT IS_ROLEMEMBER('db_datawriter', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_datawriter ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_datawriter role'
END

-- db_ddladmin: Create/modify table structures (needed for some ETL scenarios)
IF NOT IS_ROLEMEMBER('db_ddladmin', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_ddladmin ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_ddladmin role'
END

-- Grant additional permissions for bulk operations
GRANT INSERT, UPDATE, DELETE, SELECT ON SCHEMA::dbo TO [${ADF_NAME}];
PRINT 'Granted schema permissions'

-- Verify roles
SELECT 
    p.name as principal_name,
    p.type_desc as principal_type,
    r.name as role_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals p ON rm.member_principal_id = p.principal_id
WHERE p.name = '${ADF_NAME}';
EOF

# Execute the SQL script
echo "Executing SQL script to create AAD user and assign roles..."
sqlcmd -S "$SERVER" -d "$DATABASE" -U "$USERNAME" -P "$PASSWORD" -i create_aad_user.sql -C

if [ $? -eq 0 ]; then
    echo "Successfully created AAD user and assigned roles to Data Factory managed identity"
    echo '{"result": "AAD user created and roles assigned successfully"}' > $AZ_SCRIPTS_OUTPUT_PATH
else
    echo "Failed to create AAD user or assign roles"
    exit 1
fi
    '''
    environmentVariables: [
      {
        name: 'SQL_SERVER_NAME'
        value: sqlServerName
      }
      {
        name: 'DATABASE_NAME'
        value: databaseName
      }
      {
        name: 'SQL_ADMIN_USER'
        value: 'sqladminuser'
      }
      {
        name: 'SQL_ADMIN_PASSWORD'
        secureValue: sqlAdminPassword
      }
      {
        name: 'DATA_FACTORY_NAME'
        value: dataFactoryName
      }
    ]
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
  }
}

output result string = createAadUserDeployment.properties.outputs.result
