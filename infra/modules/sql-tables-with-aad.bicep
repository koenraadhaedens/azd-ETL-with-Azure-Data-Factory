param sqlServerName string
param databaseName string
param location string
param dataFactoryPrincipalId string
param dataFactoryName string
@secure()
param sqlAdminPassword string

// First deployment script: Create tables using SQL authentication (admin required for AAD setup)
resource createTablesDeployment 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'create-sql-tables-${uniqueString(resourceGroup().id)}'
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

# Create connection string
SERVER="${SQL_SERVER_NAME}.database.windows.net"
DATABASE="${DATABASE_NAME}"
USERNAME="${SQL_ADMIN_USER}"
PASSWORD="${SQL_ADMIN_PASSWORD}"
ADF_NAME="${DATA_FACTORY_NAME}"

# Create tables SQL script
cat << 'EOF' > create_tables.sql
-- Create Stores table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Stores' AND xtype='U')
BEGIN
    CREATE TABLE Stores (
        StoreId INT IDENTITY(1,1) PRIMARY KEY,
        StoreName NVARCHAR(100) NOT NULL,
        StoreLocation NVARCHAR(100),
        Region NVARCHAR(50),
        OpenDate DATE,
        StoreSize INT,
        CreatedDate DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Created Stores table'
END;

-- Create Products table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Products' AND xtype='U')
BEGIN
    CREATE TABLE Products (
        ProductId INT IDENTITY(1,1) PRIMARY KEY,
        ProductName NVARCHAR(100) NOT NULL,
        Category NVARCHAR(50),
        Brand NVARCHAR(50),
        Price DECIMAL(10,2),
        CreatedDate DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Created Products table'
END;

-- Create Sales table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Sales' AND xtype='U')
BEGIN
    CREATE TABLE Sales (
        SaleId INT IDENTITY(1,1) PRIMARY KEY,
        StoreId INT,
        ProductId INT,
        ProductName NVARCHAR(100),
        SaleDate DATE,
        Quantity INT,
        UnitPrice DECIMAL(10,2),
        TotalAmount AS (Quantity * UnitPrice) PERSISTED,
        CustomerId INT,
        CreatedDate DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (StoreId) REFERENCES Stores(StoreId)
    );
    PRINT 'Created Sales table'
END;

-- Insert sample data into Stores
IF NOT EXISTS (SELECT * FROM Stores)
BEGIN
    INSERT INTO Stores (StoreName, StoreLocation, Region, OpenDate, StoreSize)
    VALUES 
        ('Downtown Store', 'New York, NY', 'Northeast', '2020-01-15', 5000),
        ('Mall Store', 'Los Angeles, CA', 'West', '2019-06-20', 3500),
        ('Suburban Store', 'Chicago, IL', 'Midwest', '2021-03-10', 4200);
    PRINT 'Inserted sample data into Stores'
END;

-- Insert sample data into Products  
IF NOT EXISTS (SELECT * FROM Products)
BEGIN
    INSERT INTO Products (ProductName, Category, Brand, Price)
    VALUES
        ('Laptop Pro', 'Electronics', 'TechBrand', 1299.99),
        ('Wireless Mouse', 'Electronics', 'TechBrand', 29.99),
        ('Office Chair', 'Furniture', 'ComfortSeating', 249.99),
        ('Coffee Mug', 'Kitchen', 'HomeGoods', 12.99);
    PRINT 'Inserted sample data into Products'
END;
EOF

# Create AAD user and assign roles SQL script
cat << EOF > create_aad_user.sql
-- Create user for Azure Data Factory managed identity
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${ADF_NAME}')
BEGIN
    CREATE USER [${ADF_NAME}] FROM EXTERNAL PROVIDER;
    PRINT 'Created user for Data Factory managed identity: ${ADF_NAME}'
END
ELSE
BEGIN
    PRINT 'User for Data Factory managed identity already exists: ${ADF_NAME}'
END

-- Assign necessary roles for ETL operations
-- db_datareader: Read data from tables
IF NOT IS_ROLEMEMBER('db_datareader', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_datareader role to ${ADF_NAME}'
END
ELSE
BEGIN
    PRINT 'db_datareader role already assigned to ${ADF_NAME}'
END

-- db_datawriter: Write data to tables
IF NOT IS_ROLEMEMBER('db_datawriter', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_datawriter ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_datawriter role to ${ADF_NAME}'
END
ELSE
BEGIN
    PRINT 'db_datawriter role already assigned to ${ADF_NAME}'
END

-- db_ddladmin: Create/modify table structures (needed for some ETL scenarios)
IF NOT IS_ROLEMEMBER('db_ddladmin', '${ADF_NAME}') = 1
BEGIN
    ALTER ROLE db_ddladmin ADD MEMBER [${ADF_NAME}];
    PRINT 'Added db_ddladmin role to ${ADF_NAME}'
END
ELSE
BEGIN
    PRINT 'db_ddladmin role already assigned to ${ADF_NAME}'
END

-- Grant additional permissions for bulk operations
BEGIN TRY
    GRANT INSERT, UPDATE, DELETE, SELECT ON SCHEMA::dbo TO [${ADF_NAME}];
    PRINT 'Granted schema permissions to ${ADF_NAME}'
END TRY
BEGIN CATCH
    PRINT 'Schema permissions may already be granted or error occurred'
END CATCH

-- Verify roles assigned
PRINT 'Current roles for ${ADF_NAME}:'
SELECT 
    r.name as role_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals p ON rm.member_principal_id = p.principal_id
WHERE p.name = '${ADF_NAME}';
EOF

echo "Step 1: Creating tables and sample data..."
sqlcmd -S "$SERVER" -d "$DATABASE" -U "$USERNAME" -P "$PASSWORD" -i create_tables.sql -C

if [ $? -ne 0 ]; then
    echo "Failed to create tables"
    exit 1
fi

echo "Step 2: Creating AAD user and assigning roles..."
sqlcmd -S "$SERVER" -d "$DATABASE" -U "$USERNAME" -P "$PASSWORD" -i create_aad_user.sql -C

if [ $? -eq 0 ]; then
    echo "Successfully completed all SQL setup tasks!"
    echo '{"result": "Tables created and AAD user configured successfully"}' > $AZ_SCRIPTS_OUTPUT_PATH
else
    echo "Failed to configure AAD user - this may be due to permissions or existing configuration"
    # Still report success for tables creation
    echo '{"result": "Tables created successfully, AAD user configuration may need manual setup"}' > $AZ_SCRIPTS_OUTPUT_PATH
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

output result string = createTablesDeployment.properties.outputs.result
