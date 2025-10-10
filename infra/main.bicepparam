using 'main.bicep'

// Environment configuration
param environmentName = 'dev-etl'
param location = 'East US'

// SQL Server configuration
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD', '')

// Azure Data Factory IP ranges for SQL Server firewall
// Update these based on your deployment region
// For East US region (update if deploying to different region)
param dataFactoryIPRanges = [
  { start: '20.42.2.0', end: '20.42.2.255' }    // East US ADF Integration Runtime
  { start: '20.42.4.0', end: '20.42.4.255' }    // East US ADF Integration Runtime  
  { start: '20.42.5.0', end: '20.42.5.255' }    // East US ADF Integration Runtime
  { start: '40.71.14.32', end: '40.71.14.63' }  // East US ADF Integration Runtime
]

// Alternative configurations for other regions (uncomment as needed):

// West US 2:
// param dataFactoryIPRanges = [
//   { start: '20.42.130.0', end: '20.42.130.255' }
//   { start: '20.42.132.0', end: '20.42.132.255' }
//   { start: '40.78.242.96', end: '40.78.242.127' }
// ]

// West Europe:
// param dataFactoryIPRanges = [
//   { start: '20.43.40.0', end: '20.43.40.255' }
//   { start: '20.43.42.0', end: '20.43.42.255' }
//   { start: '40.74.26.0', end: '40.74.26.31' }
// ]

// Central US:
// param dataFactoryIPRanges = [
//   { start: '20.45.123.0', end: '20.45.123.255' }
//   { start: '40.113.200.0', end: '40.113.200.31' }
// ]
