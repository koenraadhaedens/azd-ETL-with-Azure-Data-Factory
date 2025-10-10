param sqlServerName string
param databaseName string
param location string

// Create the tables using deployment scripts
resource createTablesScript 'Microsoft.Sql/servers/databases/extensions@2022-02-01-preview' = {
  name: '${sqlServerName}/${databaseName}/import'
  properties: {
    operationType: 'Import'
    storageUri: 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.sql/sql-database-import-bacpac/sample.bacpac'
  }
}

// Alternative approach using deployment scripts (preferred method)
resource tableDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'create-database-tables'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.3'
    scriptContent: '''
      # Install SqlServer module if not present
      if (!(Get-Module -ListAvailable -Name SqlServer)) {
          Install-Module -Name SqlServer -Force -AllowClobber
      }

      # SQL Scripts to create tables
      $createStoresTable = @"
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
          )
      END
"@

      $createSalesTable = @"
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
              TotalAmount AS (Quantity * UnitPrice),
              CustomerId INT,
              CreatedDate DATETIME2 DEFAULT GETDATE(),
              FOREIGN KEY (StoreId) REFERENCES Stores(StoreId)
          )
      END
"@

      $createProductsTable = @"
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Products' AND xtype='U')
      BEGIN
          CREATE TABLE Products (
              ProductId INT IDENTITY(1,1) PRIMARY KEY,
              ProductName NVARCHAR(100) NOT NULL,
              Category NVARCHAR(50),
              Brand NVARCHAR(50),
              Price DECIMAL(10,2),
              CreatedDate DATETIME2 DEFAULT GETDATE()
          )
      END
"@

      # Connection string components
      $serverName = $env:SQL_SERVER_NAME + ".database.windows.net"
      $databaseName = $env:DATABASE_NAME
      $userId = $env:SQL_ADMIN_USER
      $password = $env:SQL_ADMIN_PASSWORD

      # Execute SQL scripts
      try {
          Write-Output "Creating Stores table..."
          Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Username $userId -Password $password -Query $createStoresTable -Encrypt

          Write-Output "Creating Products table..."  
          Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Username $userId -Password $password -Query $createProductsTable -Encrypt

          Write-Output "Creating Sales table..."
          Invoke-Sqlcmd -ServerInstance $serverName -Database $databaseName -Username $userId -Password $password -Query $createSalesTable -Encrypt
          
          Write-Output "All tables created successfully!"
      }
      catch {
          Write-Error "Failed to create tables: $_"
          throw $_
      }
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
  }
}

@secure()
param sqlAdminPassword string

output deploymentScriptResult string = tableDeploymentScript.properties.outputs.result
