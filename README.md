# 🚀 Azure Data Factory ETL Demo with Azure Developer CLI

This project demonstrates a **real-world ETL (Extract-Transform-Load)** pipeline using **Azure Data Factory (ADF)**, **Azure Storage (Data Lake Gen2)**, and **Azure SQL Database** — all deployed automatically using **Azure Developer CLI (azd)** and **modular Bicep templates**.

---

## 🧩 Scenario Overview

A retail company collects daily sales data from multiple branches as CSV files stored in an on-premises system (simulated here using Azure Blob Storage). The goal is to:

1. **Extract** raw data from the “on-premises” folder (Blob container `raw`)
2. **Transform** the data in Azure Data Factory by:
   - Joining with store reference data
   - Cleaning missing values
   - Calculating profit
3. **Load** the processed data into an **Azure SQL Database**
4. (Optional) **Visualize** the results in Power BI

---

## 🏗️ Architecture

```
   ┌──────────────────────────────┐
   │  On-prem / Raw Data (CSV)   │
   │  → Azure Storage (raw/)     │
   └──────────────┬──────────────┘
                  │
                  ▼
        ┌─────────────────────────────┐
        │ Azure Data Factory (ADF)    │
        │  • Copy data to staging     │
        │  • Transform (join, profit) │
        │  • Load to SQL DB           │
        └──────────────┬──────────────┘
                       │
                       ▼
          ┌──────────────────────────┐
          │ Azure SQL Database        │
          │  • Cleaned Sales Data     │
          └──────────────────────────┘
```


## 🧱 Deployed Resources

| Resource | Purpose |
|-----------|----------|
| **Resource Group** | Container for all demo resources |
| **Storage Account** | Simulates on-prem/raw data source (`raw` container) |
| **Azure SQL Database** | Destination for cleaned, transformed data |
| **Azure Data Factory** | ETL orchestration and transformation layer |

---

## ⚙️ Prerequisites

Make sure you have:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed  
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed  
- Permissions to create resource groups and resources in your Azure subscription  

---

## 🚀 Deployment Steps

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/koenraadhaedens/azd-ETL-with-Azure-Data-Factory
cd azure-etl-adf-demo
```

### 2️⃣ Initialize the Project

```bash
azd init --template .
```

### 3️⃣ Log In to Azure

```bash
azd auth login
```

### 4️⃣ Provision the Infrastructure

```bash
azd up
```

During deployment:
- You’ll be asked to enter:
  - `environmentName` (e.g., `dev`, `test`, `demo`)
  - `location` (e.g., `westeurope`)
  - SQL administrator password (stored securely)

This will:
- Create a new resource group (`rg-<environmentName>`)
- Deploy Storage, SQL, and Data Factory
- Output resource names and connection strings

Example output:
```
✔ Resource group: rg-demo
✔ Storage account: demoestore
✔ SQL server: demoesql
✔ SQL database: salesdb
✔ Data Factory: demoeadf
```

---

## 🧪 Post-Deployment Steps

1. **Upload Sample Data**

   Upload your CSV files (e.g., `sales.csv` and `stores.csv`) to the `raw` container of your storage account:

   ```bash
   az storage blob upload-batch      --account-name <storageAccountName>      --source ./data      --destination raw
   ```

2. **Open Azure Data Factory Studio**

   In the Azure Portal, navigate to your Data Factory instance → **"Launch Studio"**  
   Create a new pipeline that:
   - Copies data from the Blob storage `raw` container to a staging area
   - Uses a **Mapping Data Flow** to join and clean data
   - Loads output to your SQL database

3. **Verify Results**

   Query the SQL database:

   ```sql
   SELECT TOP 10 * FROM dbo.SalesFact;
   ```

4. *(Optional)* Connect Power BI Desktop to the SQL Database for reporting.

---

## 🧹 Cleanup

When you’re done, remove all resources:

```bash
azd down
```

---

## 🧠 Key Learnings

- How to **orchestrate ETL pipelines** using Azure Data Factory  
- How to **modularize infrastructure as code** with Bicep and `azd`  
- How to deploy consistent environments automatically using `azd up`  

---

## 🪄 Next Steps

You can extend this demo by:
- Adding a **post-provision step** to upload CSVs automatically  
- Deploying a **Data Factory pipeline definition** (JSON ARM resource)  
- Integrating **Power BI** for reporting  

---

**Author:** Kenraad Haedens
**Demo Type:** ETL with Azure Data Factory  
**Deployment Tool:** Azure Developer CLI (azd)  
**Duration:** ~15 minutes for full setup
