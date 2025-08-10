# Use the official .NET 9 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src
# Disable NuGet fallback folders for cloud builds
ENV NUGET_FALLBACK_PACKAGES=""

# Set environment variables for reliable builds
ENV NUGET_XMLDOC_MODE=skip
ENV DOTNET_NOLOGO=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# Copy project files
COPY TodoList.csproj .
COPY TodoList.sln .

# Restore packages with verbose logging and forced cache refresh, and disable fallback folders
RUN dotnet restore TodoList.csproj --verbosity normal --force --no-cache /p:RestoreFallbackFolders=""

# Copy source code
COPY . .

# Build the application with fallback folders disabled
RUN dotnet build TodoList.csproj -c Release --no-restore /p:RestoreFallbackFolders=""

# Publish the application
RUN dotnet publish TodoList.csproj -c Release --no-build -o /app/publish

# Use the official .NET 9 runtime image for the final stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy the published application
COPY --from=build /app/publish .

# Change ownership to the non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8080

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the application
ENTRYPOINT ["dotnet", "TodoList.dll"]
