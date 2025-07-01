# Azure Deployment Best Practices with GitHub Actions and Bicep

This document outlines comprehensive best practices for deploying .NET applications to Azure using GitHub Actions and Bicep Infrastructure as Code (IaC).

## Table of Contents

- [Overview](#overview)
- [Security Best Practices](#security-best-practices)
- [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline)
- [Bicep Infrastructure as Code](#bicep-infrastructure-as-code)
- [Container and Application Deployment](#container-and-application-deployment)
- [Monitoring and Logging](#monitoring-and-logging)
- [Cost Optimization](#cost-optimization)
- [Production Readiness](#production-readiness)
- [Troubleshooting](#troubleshooting)

## Overview

### Why GitHub Actions + Bicep?

- **GitHub Actions**: Native CI/CD integration with GitHub repositories
- **Bicep**: Modern, type-safe ARM template language with better tooling
- **OIDC Authentication**: Secure, keyless authentication without long-lived secrets
- **Infrastructure as Code**: Reproducible, version-controlled infrastructure
- **Container-First**: Modern cloud-native deployment patterns

### Architecture Components

- **Azure Container Apps**: Serverless container platform with auto-scaling
- **Azure Container Registry**: Private container image registry
- **Azure PostgreSQL Flexible Server**: Managed database service
- **Azure Key Vault**: Centralized secrets management
- **Azure Application Insights**: Application performance monitoring
- **Azure Log Analytics**: Centralized logging and monitoring

## Security Best Practices

### 1. Authentication and Authorization

#### OpenID Connect (OIDC) Setup
Use OIDC federated identity credentials instead of service principals with secrets:

```bash
# Create Azure AD Application
az ad app create --display-name "TodoList-GitHub-Actions"

# Create service principal
az ad sp create --id <app-id>

# Create federated identity credential
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "TodoList-GitHub-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:your-org/your-repo:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### GitHub Repository Configuration
Store sensitive values as GitHub Secrets, non-sensitive as Variables:

**Secrets:**
- `POSTGRES_ADMIN_PASSWORD`: Database admin password

**Variables:**
- `AZURE_CLIENT_ID`: Azure AD Application ID
- `AZURE_TENANT_ID`: Azure AD Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID
- `AZURE_LOCATION`: Deployment region

### 2. Managed Identity and RBAC

#### User-Assigned Managed Identity
```bicep
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${resourceToken}'
  location: location
  tags: tags
}

// Grant Container Registry pull permissions
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, managedIdentity.id, 'acrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

#### Key Vault Access
```bicep
resource keyVaultSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, managedIdentity.id, 'keyVaultSecretUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### 3. Network Security

#### Private Endpoints
```bicep
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-${keyVault.name}'
  location: location
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultConnection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}
```

#### Database Security
```bicep
resource postgreSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: 'psql-${resourceToken}'
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'adminuser'
    administratorLoginPassword: postgresPassword
    version: '15'
    storage: {
      storageSizeGB: 32
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Disabled'  // Use private access only
    }
  }
}
```

## GitHub Actions CI/CD Pipeline

### 1. Workflow Structure

#### Complete Workflow Example
```yaml
name: Deploy to Azure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  REGISTRY_NAME: '${{ vars.AZURE_CONTAINER_REGISTRY }}'
  IMAGE_NAME: 'todolist-app'
  RESOURCE_GROUP: 'rg-todolist-${{ vars.AZURE_LOCATION }}'

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: Restore dependencies
        run: dotnet restore

      - name: Build application
        run: dotnet build --no-restore --configuration Release

      - name: Run tests
        run: dotnet test --no-build --configuration Release --verbosity normal

      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Login to Azure Container Registry
        run: az acr login --name ${{ env.REGISTRY_NAME }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push container image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy-infrastructure:
    runs-on: ubuntu-latest
    needs: build
    environment: production
    outputs:
      container-app-fqdn: ${{ steps.deploy.outputs.containerAppFQDN }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy Bicep template
        id: deploy
        uses: azure/arm-deploy@v1
        with:
          subscriptionId: ${{ vars.AZURE_SUBSCRIPTION_ID }}
          resourceGroupName: ${{ env.RESOURCE_GROUP }}
          template: ./infra/main.bicep
          parameters: >
            location=${{ vars.AZURE_LOCATION }}
            containerImageTag=${{ needs.build.outputs.image-tag }}
            postgresAdminPassword=${{ secrets.POSTGRES_ADMIN_PASSWORD }}
          failOnStdErr: false

  deploy-application:
    runs-on: ubuntu-latest
    needs: [build, deploy-infrastructure]
    environment: production
    steps:
      - name: Azure login
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Update Container App
        run: |
          az containerapp update \
            --name ca-todolist-${{ vars.AZURE_LOCATION }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --image ${{ needs.build.outputs.image-tag }}

      - name: Verify deployment
        run: |
          echo "Application deployed to: https://${{ needs.deploy-infrastructure.outputs.container-app-fqdn }}"
          curl -f https://${{ needs.deploy-infrastructure.outputs.container-app-fqdn }}/health || exit 1
```

### 2. Multi-Environment Strategy

#### Environment-Specific Deployments
```yaml
strategy:
  matrix:
    environment: [development, staging, production]
    include:
      - environment: development
        resource-group-suffix: dev
        sku: Consumption
      - environment: staging
        resource-group-suffix: staging
        sku: Standard
      - environment: production
        resource-group-suffix: prod
        sku: Standard
```

#### Branch-Based Deployments
```yaml
on:
  push:
    branches:
      - main      # Deploy to production
      - develop   # Deploy to staging
      - 'feature/*' # Deploy to development
```

### 3. Security Scanning

#### Container Security Scanning
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.meta.outputs.tags }}
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

## Bicep Infrastructure as Code

### 1. Project Structure
```
infra/
├── main.bicep                 # Main template
├── main.parameters.json       # Parameter file
├── modules/
│   ├── container-app.bicep    # Container Apps module
│   ├── database.bicep         # Database module
│   ├── monitoring.bicep       # Monitoring module
│   └── networking.bicep       # Networking module
└── scripts/
    └── deploy.ps1             # Deployment script
```

### 2. Parameter Management

#### main.parameters.json
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "East US"
    },
    "environment": {
      "value": "production"
    },
    "containerImageTag": {
      "value": "latest"
    }
  }
}
```

#### Secure Parameters
```bicep
@secure()
@minLength(12)
param postgresAdminPassword string

@allowed(['development', 'staging', 'production'])
param environment string = 'development'

@minLength(3)
@maxLength(24)
param applicationName string = 'todolist'
```

### 3. Resource Naming and Tagging

#### Consistent Naming Convention
```bicep
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)
var tags = {
  Environment: environment
  Application: applicationName
  'Deployed-By': 'GitHub-Actions'
  'Cost-Center': 'Engineering'
  'Created-Date': utcNow('yyyy-MM-dd')
}

var names = {
  containerApp: 'ca-${applicationName}-${resourceToken}'
  containerRegistry: 'acr${applicationName}${resourceToken}'
  keyVault: 'kv-${applicationName}-${resourceToken}'
  logAnalytics: 'law-${applicationName}-${resourceToken}'
  appInsights: 'ai-${applicationName}-${resourceToken}'
  postgreSQL: 'psql-${applicationName}-${resourceToken}'
  managedIdentity: 'id-${applicationName}-${resourceToken}'
}
```

### 4. Modular Design

#### Container App Module
```bicep
@description('Container App configuration')
param containerAppConfig object

@description('Environment variables for the container')
param environmentVariables array = []

@description('Container image tag')
param containerImageTag string

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppConfig.name
  location: containerAppConfig.location
  tags: containerAppConfig.tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppConfig.managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppConfig.environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerAppConfig.registryServer
          identity: containerAppConfig.managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'postgres-connection-string'
          keyVaultUrl: containerAppConfig.postgresConnectionStringUrl
          identity: containerAppConfig.managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'todolist-app'
          image: '${containerAppConfig.registryServer}/${containerImageTag}'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: union(environmentVariables, [
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'postgres-connection-string'
            }
          ])
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}
```

### 5. Output Management

#### Structured Outputs
```bicep
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output keyVaultName string = keyVault.name
output containerRegistryName string = containerRegistry.name
output postgresServerName string = postgreSQL.name

output deploymentInfo object = {
  resourceGroup: resourceGroup().name
  location: location
  environment: environment
  timestamp: utcNow()
  resources: {
    containerApp: containerApp.name
    keyVault: keyVault.name
    containerRegistry: containerRegistry.name
    postgreSQL: postgreSQL.name
  }
}
```

## Container and Application Deployment

### 1. Multi-Stage Dockerfile

#### Optimized Production Dockerfile
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project files and restore dependencies
COPY *.csproj ./
COPY *.sln ./
RUN dotnet restore --verbosity normal --force --no-cache

# Copy source code and build
COPY . .
RUN dotnet build -c Release --no-restore
RUN dotnet publish -c Release --no-build -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=build /app/publish .

# Set ownership and switch to non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
ENTRYPOINT ["dotnet", "TodoList.dll"]
```

### 2. Configuration Management

#### Application Configuration Best Practices
```csharp
public static void ConfigureServices(WebApplicationBuilder builder)
{
    // Database configuration with fallback
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    if (!string.IsNullOrEmpty(connectionString) && connectionString.Contains("Host="))
    {
        builder.Services.AddDbContext<TodoDbContext>(options =>
            options.UseNpgsql(connectionString, npgsqlOptions =>
            {
                npgsqlOptions.EnableRetryOnFailure(
                    maxRetryCount: 3,
                    maxRetryDelay: TimeSpan.FromSeconds(30),
                    errorCodesToAdd: null);
            }));
    }
    else
    {
        var sqliteConnection = builder.Configuration.GetConnectionString("SqliteConnection") 
                            ?? "Data Source=todolist.db";
        builder.Services.AddDbContext<TodoDbContext>(options =>
            options.UseSqlite(sqliteConnection));
    }

    // Health checks
    builder.Services.AddHealthChecks()
        .AddDbContextCheck<TodoDbContext>()
        .AddCheck("self", () => HealthCheckResult.Healthy());

    // Application Insights
    builder.Services.AddApplicationInsightsTelemetry();

    // Logging
    builder.Services.AddLogging(logging =>
    {
        logging.AddConsole();
        logging.AddApplicationInsights();
    });
}
```

### 3. Environment-Specific Configuration

#### appsettings.Production.json
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": ""
  },
  "ApplicationInsights": {
    "ConnectionString": ""
  },
  "HealthChecks": {
    "UI": {
      "HealthCheckDatabaseConnectionString": ""
    }
  }
}
```

## Monitoring and Logging

### 1. Application Insights Integration

#### Telemetry Configuration
```csharp
public static void ConfigureMonitoring(WebApplicationBuilder builder)
{
    // Application Insights
    builder.Services.AddApplicationInsightsTelemetry(options =>
    {
        options.EnableAdaptiveSampling = true;
        options.InstrumentationKey = builder.Configuration["ApplicationInsights:InstrumentationKey"];
    });

    // Custom telemetry
    builder.Services.AddSingleton<ITelemetryInitializer, CustomTelemetryInitializer>();
    
    // Request tracking
    builder.Services.Configure<TelemetryConfiguration>(config =>
    {
        config.TelemetryInitializers.Add(new OperationCorrelationTelemetryInitializer());
    });
}
```

#### Custom Telemetry Initializer
```csharp
public class CustomTelemetryInitializer : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
    {
        if (telemetry is RequestTelemetry requestTelemetry)
        {
            requestTelemetry.Properties["Application"] = "TodoList";
            requestTelemetry.Properties["Environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        }
    }
}
```

### 2. Structured Logging

#### Logging Configuration
```csharp
public static void ConfigureLogging(WebApplicationBuilder builder)
{
    builder.Services.AddLogging(logging =>
    {
        logging.ClearProviders();
        logging.AddConsole(options =>
        {
            options.IncludeScopes = true;
            options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
        });
        
        if (builder.Environment.IsProduction())
        {
            logging.AddApplicationInsights();
        }
    });

    // Structured logging with Serilog
    Log.Logger = new LoggerConfiguration()
        .ReadFrom.Configuration(builder.Configuration)
        .Enrich.FromLogContext()
        .Enrich.WithProperty("Application", "TodoList")
        .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}")
        .CreateLogger();

    builder.Host.UseSerilog();
}
```

### 3. Health Checks

#### Comprehensive Health Checks
```csharp
public static void ConfigureHealthChecks(WebApplicationBuilder builder)
{
    builder.Services.AddHealthChecks()
        .AddDbContextCheck<TodoDbContext>("database")
        .AddCheck<ExternalApiHealthCheck>("external-api")
        .AddCheck("memory", () =>
        {
            var allocatedBytes = GC.GetTotalMemory(false);
            var threshold = 1024 * 1024 * 1024; // 1 GB
            return allocatedBytes < threshold ? 
                HealthCheckResult.Healthy($"Memory usage: {allocatedBytes / 1024 / 1024} MB") :
                HealthCheckResult.Degraded($"High memory usage: {allocatedBytes / 1024 / 1024} MB");
        })
        .AddCheck("disk-space", () =>
        {
            var drive = new DriveInfo(Path.GetPathRoot(Directory.GetCurrentDirectory()));
            var freeSpaceGB = drive.AvailableFreeSpace / 1024 / 1024 / 1024;
            return freeSpaceGB > 1 ? 
                HealthCheckResult.Healthy($"Free disk space: {freeSpaceGB} GB") :
                HealthCheckResult.Unhealthy($"Low disk space: {freeSpaceGB} GB");
        });

    builder.Services.Configure<HealthCheckPublisherOptions>(options =>
    {
        options.Delay = TimeSpan.FromSeconds(2);
        options.Period = TimeSpan.FromSeconds(30);
    });
}
```

## Cost Optimization

### 1. Resource Sizing

#### Environment-Based Scaling
```bicep
var containerAppConfig = {
  development: {
    cpu: json('0.25')
    memory: '0.5Gi'
    minReplicas: 0
    maxReplicas: 2
  }
  staging: {
    cpu: json('0.5')
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 5
  }
  production: {
    cpu: json('1.0')
    memory: '2Gi'
    minReplicas: 2
    maxReplicas: 20
  }
}

var dbConfig = {
  development: {
    sku: 'Standard_B1ms'
    tier: 'Burstable'
    storage: 32
  }
  staging: {
    sku: 'Standard_B2s'
    tier: 'Burstable'
    storage: 64
  }
  production: {
    sku: 'Standard_D2s_v3'
    tier: 'GeneralPurpose'
    storage: 128
  }
}
```

### 2. Auto-Scaling Configuration

#### Intelligent Scaling Rules
```bicep
scale: {
  minReplicas: containerAppConfig[environment].minReplicas
  maxReplicas: containerAppConfig[environment].maxReplicas
  rules: [
    {
      name: 'http-scaling-rule'
      http: {
        metadata: {
          concurrentRequests: '30'
        }
      }
    }
    {
      name: 'cpu-scaling-rule'
      custom: {
        type: 'cpu'
        metadata: {
          type: 'Utilization'
          value: '70'
        }
      }
    }
    {
      name: 'memory-scaling-rule'
      custom: {
        type: 'memory'
        metadata: {
          type: 'Utilization'
          value: '80'
        }
      }
    }
  ]
}
```

### 3. Cost Monitoring

#### Budget Alerts
```bicep
resource budget 'Microsoft.Consumption/budgets@2021-10-01' = {
  name: 'budget-${applicationName}-${environment}'
  properties: {
    timePeriod: {
      startDate: '2024-01-01'
      endDate: '2025-12-31'
    }
    timeGrain: 'Monthly'
    amount: environment == 'production' ? 500 : 100
    category: 'Cost'
    notifications: {
      'budget-exceeded': {
        enabled: true
        operator: 'GreaterThan'
        threshold: 90
        contactEmails: [
          'devops@company.com'
        ]
      }
    }
  }
}
```

## Production Readiness

### 1. Zero-Downtime Deployments

#### Blue-Green Deployment Strategy
```bicep
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        traffic: [
          {
            revisionName: '${containerAppName}--${newRevisionSuffix}'
            weight: 100
          }
        ]
      }
    }
  }
}
```

#### Rolling Update Configuration
```yaml
- name: Deploy with rolling update
  run: |
    az containerapp update \
      --name ${{ env.CONTAINER_APP_NAME }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --image ${{ needs.build.outputs.image-tag }} \
      --revision-suffix $(date +%Y%m%d-%H%M%S)
```

### 2. Database Migration Strategy

#### Safe Migration Practices
```csharp
public static async Task ConfigureDatabaseAsync(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    try
    {
        if (app.Environment.IsProduction())
        {
            // Production: Apply pending migrations
            var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
            if (pendingMigrations.Any())
            {
                logger.LogInformation("Applying {Count} pending migrations", pendingMigrations.Count());
                await context.Database.MigrateAsync();
            }
        }
        else
        {
            // Development: Ensure database is created
            await context.Database.EnsureCreatedAsync();
        }
        
        // Seed initial data
        await SeedDataAsync(context, logger);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database initialization failed");
        throw;
    }
}
```

### 3. Performance Optimization

#### Connection Pooling and Caching
```csharp
public static void ConfigurePerformance(WebApplicationBuilder builder)
{
    // Entity Framework connection pooling
    builder.Services.AddDbContextPool<TodoDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"),
            npgsqlOptions =>
            {
                npgsqlOptions.EnableRetryOnFailure();
                npgsqlOptions.CommandTimeout(30);
            })
        .EnableServiceProviderCaching()
        .EnableSensitiveDataLogging(builder.Environment.IsDevelopment()));

    // Response caching
    builder.Services.AddResponseCaching();
    
    // Output caching
    builder.Services.AddOutputCache(options =>
    {
        options.AddBasePolicy(builder => builder.Cache());
        options.AddPolicy("TodosCache", builder => 
            builder.Cache()
                   .Expire(TimeSpan.FromMinutes(5))
                   .Tag("todos"));
    });

    // HTTP client configuration
    builder.Services.AddHttpClient();
    builder.Services.Configure<HttpClientFactoryOptions>(options =>
    {
        options.HttpMessageHandlerBuilderActions.Add(builder =>
        {
            builder.PrimaryHandler = new SocketsHttpHandler
            {
                PooledConnectionLifetime = TimeSpan.FromMinutes(15)
            };
        });
    });
}
```

## Troubleshooting

### 1. Common Deployment Issues

#### Authentication Problems
```yaml
# Debug OIDC authentication
- name: Debug Azure login
  run: |
    echo "Client ID: ${{ vars.AZURE_CLIENT_ID }}"
    echo "Tenant ID: ${{ vars.AZURE_TENANT_ID }}"
    echo "Subscription ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}"
    az account show
```

#### Container Registry Issues
```bash
# Check ACR permissions
az acr check-health --name myregistry

# Test container pull
az acr repository show-tags --name myregistry --repository todolist-app

# Verify managed identity permissions
az role assignment list --assignee <managed-identity-id> --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.ContainerRegistry/registries/<acr-name>
```

### 2. Application Debugging

#### Container Logs
```bash
# Container Apps logs
az containerapp logs show \
  --name ca-todolist-eastus \
  --resource-group rg-todolist-prod \
  --follow

# Application Insights queries
az monitor app-insights query \
  --app ai-todolist-eastus \
  --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"
```

#### Database Connectivity
```bash
# Test database connection
az postgres flexible-server connect \
  --name psql-todolist-eastus \
  --admin-user adminuser \
  --admin-password <password> \
  --database todolistdb
```

### 3. Performance Monitoring

#### Application Performance
```kusto
// Application Insights KQL queries

// Response time trends
requests
| where timestamp > ago(24h)
| summarize avg(duration), percentile(duration, 95) by bin(timestamp, 1h)
| render timechart

// Error rate analysis
requests
| where timestamp > ago(24h)
| summarize total = count(), errors = countif(success == false) by bin(timestamp, 1h)
| extend error_rate = (errors * 100.0) / total
| render timechart

// Dependency performance
dependencies
| where timestamp > ago(24h)
| summarize avg(duration), percentile(duration, 95) by name
| order by avg_duration desc
```

### 4. Cost Analysis

#### Resource Cost Breakdown
```bash
# Cost analysis by resource group
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --resource-group rg-todolist-prod

# Budget alerts
az consumption budget list \
  --resource-group rg-todolist-prod
```

## Conclusion

This comprehensive guide provides a production-ready foundation for deploying .NET applications to Azure using modern DevOps practices. Key takeaways:

1. **Security First**: Use OIDC, managed identities, and least privilege access
2. **Infrastructure as Code**: Bicep templates for reproducible deployments
3. **Observability**: Comprehensive monitoring and logging
4. **Cost Optimization**: Right-sized resources with intelligent scaling
5. **Reliability**: Health checks, retries, and graceful error handling

By following these best practices, you'll have a robust, secure, and cost-effective deployment pipeline that scales with your application needs.

## Additional Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Bicep Language Reference](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/)
- [.NET Performance Best Practices](https://docs.microsoft.com/en-us/dotnet/core/performance/)
