param sqlServerName string
param databaseName string
param location string
@secure()
param sqlAdminPassword string

// Using deployment scripts to create tables
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
END;

-- Insert sample data into Stores
IF NOT EXISTS (SELECT * FROM Stores)
BEGIN
    INSERT INTO Stores (StoreName, StoreLocation, Region, OpenDate, StoreSize)
    VALUES 
        ('Downtown Store', 'New York, NY', 'Northeast', '2020-01-15', 5000),
        ('Mall Store', 'Los Angeles, CA', 'West', '2019-06-20', 3500),
        ('Suburban Store', 'Chicago, IL', 'Midwest', '2021-03-10', 4200);
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
END;
EOF

# Execute SQL script
echo "Connecting to SQL Server and creating tables..."
sqlcmd -S "$SERVER" -d "$DATABASE" -U "$USERNAME" -P "$PASSWORD" -i create_tables.sql -C

if [ $? -eq 0 ]; then
    echo "Tables created successfully!"
    echo '{"result": "Tables created successfully"}' > $AZ_SCRIPTS_OUTPUT_PATH
else
    echo "Failed to create tables"
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
    ]
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
  }
}

output tablesCreated string = createTablesDeployment.properties.outputs.result
