# TodoList - .NET Blazor with PostgreSQL

A modern Todo application built with .NET 9 Blazor Server and PostgreSQL, featuring both web UI and MCP (Model Context Protocol) integration. Deployable to Azure using GitHub Actions and Bicep Infrastructure as Code.

## Features

- **Blazor Server UI**: Interactive web interface for managing todos
- **PostgreSQL Database**: Production-ready data storage with SQLite fallback
- **MCP Integration**: Model Context Protocol support for AI tool integration
- **Docker Support**: Full containerization with Docker Compose
- **REST API**: Clean RESTful endpoints for todo operations
- **Health Checks**: Built-in health monitoring
- **Azure Deployment**: CI/CD pipeline with GitHub Actions and Bicep

## Quick Start

### Local Development

#### With Docker (Recommended)

```bash
# Start the application with PostgreSQL
docker-compose up -d

# The application will be available at:
# - Web UI: http://localhost:8080
# - Health Check: http://localhost:8080/health
# - MCP API: http://localhost:8080/mcp/todos
```

#### Local .NET Development

```bash
# Install dependencies
dotnet restore

# Run with SQLite fallback
dotnet run

# The application will be available at:
# - Web UI: http://localhost:5000
# - Health Check: http://localhost:5000/health
# - MCP API: http://localhost:5000/mcp/todos
```

### Azure Deployment

#### Prerequisites
- Azure subscription
- GitHub repository
- Azure CLI installed locally

#### Setup OIDC Authentication

**Windows (PowerShell):**
```powershell
.\scripts\setup-azure-oidc.ps1 -GitHubOrg "your-org" -GitHubRepo "your-repo"
```

**Linux/macOS:**
```bash
chmod +x scripts/setup-azure-oidc.sh
./scripts/setup-azure-oidc.sh
```

#### Configure GitHub Repository

1. Go to your GitHub repository settings
2. Navigate to "Secrets and variables" > "Actions" > "Variables"
3. Add the following repository variables:

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `AZURE_CLIENT_ID` | `<from setup script>` | Azure AD Application ID |
| `AZURE_TENANT_ID` | `<your tenant ID>` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `<your subscription ID>` | Azure Subscription ID |
| `AZURE_LOCATION` | `eastus` | Azure region for deployment |

4. Add the following repository secret:
   - `POSTGRES_ADMIN_PASSWORD`: Secure password for PostgreSQL admin user

#### Deploy

Push to the `main` branch to trigger automatic deployment:

```bash
git add .
git commit -m "Deploy TodoList to Azure"
git push origin main
```

Or trigger manual deployment from GitHub Actions tab.

## API Endpoints

### Health Check
- `GET /health` - Application health status

### REST API
- `GET /mcp/todos` - Get all todos
- `POST /mcp/todos` - Add new todo
- `PUT /mcp/todos/{title}` - Update todo status
- `DELETE /mcp/todos/{title}` - Remove todo

### MCP Protocol
- `POST /mcp` - MCP protocol endpoint for AI tool integration

## Database Setup

### PostgreSQL (Docker)
The PostgreSQL database is automatically initialized with Docker Compose.

### Manual PostgreSQL Setup
If you want to set up PostgreSQL manually:

```bash
# Run the setup script
./setup-database.ps1
```

### SQLite Fallback
The application automatically falls back to SQLite if PostgreSQL is not available.

## Configuration

### Connection Strings
- **PostgreSQL**: `Host=localhost;Database=todolistdb;Username=admin;Password=password`
- **SQLite**: `Data Source=todolist.db`

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Set to `Development` or `Production`
- `ConnectionStrings__DefaultConnection`: Override default connection string

## Architecture

### Application Structure
- **Program.cs**: Clean, modular configuration with separated concerns
- **TodoDbContext.cs**: Entity Framework Core database context
- **TodoListService.cs**: Async-only business logic and data access layer
- **TodoItem.cs**: Data model with EF Core attributes
- **Components/**: Blazor components and pages

### Azure Architecture
- **Azure Container Apps**: Serverless container hosting with auto-scaling
- **Azure PostgreSQL Flexible Server**: Managed database service
- **Azure Container Registry**: Private container image storage
- **Azure Key Vault**: Secure secrets management
- **Azure Log Analytics**: Centralized logging and monitoring
- **Application Insights**: Application performance monitoring
- **Managed Identity**: Secure service-to-service authentication

### Key Features
- ✅ **Simplified Architecture**: Single app instance serving both web UI and MCP endpoints
- ✅ **Async-First**: All database operations are async for better performance
- ✅ **Clean Separation**: Modular Program.cs with clear separation of concerns
- ✅ **RESTful API**: Modern HTTP endpoints following REST conventions
- ✅ **Proper Error Handling**: Comprehensive error handling with logging
- ✅ **Docker Optimized**: Single port (8080) for all services
- ✅ **Health Monitoring**: Enhanced health checks with environment info
- ✅ **CI/CD Pipeline**: Automated deployment with GitHub Actions
- ✅ **Infrastructure as Code**: Bicep templates for reproducible deployments
- ✅ **Secure Deployment**: OIDC authentication, managed identities, Key Vault

## Technology Stack

- .NET 9
- Blazor Server
- Entity Framework Core
- PostgreSQL / SQLite
- Docker & Docker Compose
- MCP (Model Context Protocol)
- Azure Container Apps
- Azure PostgreSQL
- GitHub Actions
- Bicep (Infrastructure as Code)

## Development

### Building
```bash
dotnet build
```

### Docker
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Azure Development
```bash
# Deploy infrastructure only
az deployment group create \
  --resource-group rg-todolist-dev \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json

# Build and push container
az acr build --registry <acr-name> --image todolist-app:latest .
```

## Troubleshooting

### Local Development Issues

#### Database Connection Issues
1. Ensure PostgreSQL is running: `docker-compose ps`
2. Check connection string in `appsettings.json`
3. Application automatically falls back to SQLite if PostgreSQL is unavailable

#### Port Conflicts
- Default ports: 8080 (web + MCP), 5432 (PostgreSQL)
- Modify `docker-compose.yml` to change port mappings

#### Container Issues
```bash
# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Azure Deployment Issues

#### Authentication Errors
- Verify OIDC federated credentials are configured correctly
- Check GitHub repository variables and secrets
- Ensure Azure CLI permissions

#### Container Image Issues
- Check Azure Container Registry permissions
- Verify managed identity has AcrPull role
- Review GitHub Actions build logs

#### Application Runtime Issues
- Check Application Insights for errors
- Review Container Apps logs: `az containerapp logs show --name <app-name> --resource-group <rg-name>`
- Verify Key Vault access and secrets

## Monitoring

### Azure Resources
After deployment, monitor your application through:
- **Azure Portal**: Container Apps, PostgreSQL, Key Vault
- **Application Insights**: Performance and error tracking
- **Log Analytics**: Centralized logging

### Local Monitoring
- Health endpoint: `/health`
- Docker logs: `docker-compose logs -f`
- Application logs in console output

## Cost Optimization

### Development Environment
- Container Apps: ~$5-10/month (minimal usage)
- PostgreSQL: ~$15-30/month (Burstable tier)
- Storage & networking: ~$5/month
- **Total**: ~$25-45/month

### Production Environment
- Container Apps: ~$50-100/month (auto-scaling)
- PostgreSQL: ~$100-200/month (General Purpose)
- Storage & networking: ~$20/month
- **Total**: ~$170-320/month

## License

This project is licensed under the MIT License.
- `POST /mcp/todos` - Add new todo
- `PUT /mcp/todos/{title}` - Update todo status
- `DELETE /mcp/todos/{title}` - Remove todo

### MCP Protocol
- `POST /mcp` - MCP protocol endpoint for AI tool integration

## Database Setup

### PostgreSQL (Docker)
The PostgreSQL database is automatically initialized with Docker Compose.

### Manual PostgreSQL Setup
If you want to set up PostgreSQL manually:

```bash
# Run the setup script
./setup-database.ps1
```

### SQLite Fallback
The application automatically falls back to SQLite if PostgreSQL is not available.

## Configuration

### Connection Strings
- **PostgreSQL**: `Host=localhost;Database=todolistdb;Username=admin;Password=password`
- **SQLite**: `Data Source=todolist.db`

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Set to `Development` or `Production`
- `ConnectionStrings__DefaultConnection`: Override default connection string

## Architecture

The application has been refactored for simplicity and maintainability:

- **Program.cs**: Clean, modular configuration with separated concerns
- **TodoDbContext.cs**: Entity Framework Core database context
- **TodoListService.cs**: Async-only business logic and data access layer
- **TodoItem.cs**: Data model with EF Core attributes
- **Components/**: Blazor components and pages

- ✅ **Simplified Architecture**: Single app instance serving both web UI and MCP endpoints
- ✅ **Async-First**: All database operations are async for better performance
- ✅ **Clean Separation**: Modular Program.cs with clear separation of concerns
- ✅ **RESTful API**: Modern HTTP endpoints following REST conventions
- ✅ **Proper Error Handling**: Comprehensive error handling with logging
- ✅ **Docker Optimized**: Single port (8080) for all services
- ✅ **Health Monitoring**: Enhanced health checks with environment info

### Map

TodoList/
├── .dockerignore
├── .gitignore  
├── .vscode/
│   └── mcp.json
├── appsettings.json
├── appsettings.Development.json
├── appsettings.Production.json
├── Components/
│   ├── App.razor
│   ├── Routes.razor
│   ├── _Imports.razor
│   ├── Layout/
│   │   ├── MainLayout.razor
│   │   └── MainLayout.razor.css
│   └── Pages/
│       ├── Error.razor
│       ├── Todo.razor
│       └── Todo.razor.css
├── database-setup.sql
├── docker-compose.yml
├── Dockerfile
├── Program.cs
├── Properties/
│   └── launchSettings.json
├── README.md
├── setup-database.ps1
├── TodoDbContext.cs
├── TodoItem.cs
├── TodoList.csproj
├── TodoList.sln
├── TodoListService.cs
└── wwwroot/
    ├── app.css
    └── favicon.png

## Technology Stack

- .NET 9
- Blazor Server
- Entity Framework Core
- PostgreSQL / SQLite
- Docker & Docker Compose
- MCP (Model Context Protocol)

## Development

### Building
```bash
dotnet build
```

### Docker
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Troubleshooting

### Database Connection Issues
1. Ensure PostgreSQL is running: `docker-compose ps`
2. Check connection string in `appsettings.json`
3. Application automatically falls back to SQLite if PostgreSQL is unavailable

### Port Conflicts
- Default ports: 8080 (web + MCP), 5432 (PostgreSQL)
- Modify `docker-compose.yml` to change port mappings

### Container Issues
```bash
# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## License

This project is licensed under the MIT License.
