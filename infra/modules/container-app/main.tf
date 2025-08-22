# Azure Container App
# Provides the application hosting with automatic scaling, traffic management, and health monitoring

resource "azurerm_container_app" "main" {
  name                         = local.container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  workload_profile_name        = var.workload_profile_name

  # Template configuration
  template {
    # Container configuration
    container {
      name   = var.container_name
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = var.secret_environment_variables
        
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      # Volume mounts
      dynamic "volume_mounts" {
        for_each = var.volume_mounts
        
        content {
          name = volume_mounts.value.name
          path = volume_mounts.value.path
        }
      }

      # Liveness probe
      dynamic "liveness_probe" {
        for_each = var.liveness_probe != null ? [var.liveness_probe] : []
        
        content {
          port                    = liveness_probe.value.port
          transport               = liveness_probe.value.transport
          failure_count_threshold = liveness_probe.value.failure_count_threshold
          host                    = liveness_probe.value.host
          initial_delay           = liveness_probe.value.initial_delay
          interval_seconds        = liveness_probe.value.interval_seconds
          path                    = liveness_probe.value.path
          timeout                 = liveness_probe.value.timeout
          
          dynamic "header" {
            for_each = liveness_probe.value.headers
            
            content {
              name  = header.value.name
              value = header.value.value
            }
          }
        }
      }

      # Readiness probe
      dynamic "readiness_probe" {
        for_each = var.readiness_probe != null ? [var.readiness_probe] : []
        
        content {
          port                    = readiness_probe.value.port
          transport               = readiness_probe.value.transport
          failure_count_threshold = readiness_probe.value.failure_count_threshold
          host                    = readiness_probe.value.host
          interval_seconds        = readiness_probe.value.interval_seconds
          path                    = readiness_probe.value.path
          success_count_threshold = readiness_probe.value.success_count_threshold
          timeout                 = readiness_probe.value.timeout
          
          dynamic "header" {
            for_each = readiness_probe.value.headers
            
            content {
              name  = header.value.name
              value = header.value.value
            }
          }
        }
      }

      # Startup probe
      dynamic "startup_probe" {
        for_each = var.startup_probe != null ? [var.startup_probe] : []
        
        content {
          port                    = startup_probe.value.port
          transport               = startup_probe.value.transport
          failure_count_threshold = startup_probe.value.failure_count_threshold
          host                    = startup_probe.value.host
          interval_seconds        = startup_probe.value.interval_seconds
          path                    = startup_probe.value.path
          timeout                 = startup_probe.value.timeout
          
          dynamic "header" {
            for_each = startup_probe.value.headers
            
            content {
              name  = header.value.name
              value = header.value.value
            }
          }
        }
      }
    }

    # Scaling configuration
    max_replicas = var.max_replicas
    min_replicas = var.min_replicas

    # HTTP scale rules
    dynamic "http_scale_rule" {
      for_each = var.http_scale_rules
      
      content {
        name                = http_scale_rule.value.name
        concurrent_requests = http_scale_rule.value.concurrent_requests
        
        dynamic "metadata" {
          for_each = http_scale_rule.value.metadata
          
          content {
            name  = metadata.value.name
            value = metadata.value.value
          }
        }
      }
    }

    # Custom scale rules
    dynamic "custom_scale_rule" {
      for_each = var.custom_scale_rules
      
      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = custom_scale_rule.value.custom_rule_type
        
        dynamic "metadata" {
          for_each = custom_scale_rule.value.metadata
          
          content {
            name  = metadata.value.name
            value = metadata.value.value
          }
        }
        
        dynamic "authentication" {
          for_each = custom_scale_rule.value.authentication != null ? [custom_scale_rule.value.authentication] : []
          
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    # Azure Queue scale rules
    dynamic "azure_queue_scale_rule" {
      for_each = var.azure_queue_scale_rules
      
      content {
        name         = azure_queue_scale_rule.value.name
        queue_name   = azure_queue_scale_rule.value.queue_name
        queue_length = azure_queue_scale_rule.value.queue_length
        
        dynamic "authentication" {
          for_each = azure_queue_scale_rule.value.authentication != null ? [azure_queue_scale_rule.value.authentication] : []
          
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    # TCP scale rules
    dynamic "tcp_scale_rule" {
      for_each = var.tcp_scale_rules
      
      content {
        name                = tcp_scale_rule.value.name
        concurrent_requests = tcp_scale_rule.value.concurrent_requests
        
        dynamic "metadata" {
          for_each = tcp_scale_rule.value.metadata
          
          content {
            name  = metadata.value.name
            value = metadata.value.value
          }
        }
        
        dynamic "authentication" {
          for_each = tcp_scale_rule.value.authentication != null ? [tcp_scale_rule.value.authentication] : []
          
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    # Volumes
    dynamic "volume" {
      for_each = var.volumes
      
      content {
        name         = volume.value.name
        storage_name = volume.value.storage_name
        storage_type = volume.value.storage_type
      }
    }

    # Init containers
    dynamic "init_container" {
      for_each = var.init_containers
      
      content {
        name    = init_container.value.name
        image   = init_container.value.image
        args    = init_container.value.args
        command = init_container.value.command
        cpu     = init_container.value.cpu
        memory  = init_container.value.memory
        
        dynamic "env" {
          for_each = init_container.value.environment_variables
          
          content {
            name  = env.key
            value = env.value
          }
        }
        
        dynamic "volume_mounts" {
          for_each = init_container.value.volume_mounts
          
          content {
            name = volume_mounts.value.name
            path = volume_mounts.value.path
          }
        }
      }
    }
  }

  # Secrets
  dynamic "secret" {
    for_each = var.secrets
    
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  # Ingress configuration
  dynamic "ingress" {
    for_each = var.enable_ingress ? [1] : []
    
    content {
      allow_insecure_connections = var.allow_insecure_connections
      external_enabled           = var.external_enabled
      target_port                = var.target_port
      transport                  = var.transport
      exposed_port               = var.exposed_port

      # Traffic weights for blue-green deployments
      dynamic "traffic_weight" {
        for_each = var.traffic_weights
        
        content {
          label           = traffic_weight.value.label
          latest_revision = traffic_weight.value.latest_revision
          revision_suffix = traffic_weight.value.revision_suffix
          percentage      = traffic_weight.value.percentage
        }
      }

      # Custom domains
      dynamic "custom_domain" {
        for_each = var.custom_domains
        
        content {
          name             = custom_domain.value.name
          binding_type     = custom_domain.value.binding_type
          certificate_id   = custom_domain.value.certificate_id
        }
      }

      # IP security restrictions
      dynamic "ip_security_restriction" {
        for_each = var.ip_security_restrictions
        
        content {
          action           = ip_security_restriction.value.action
          ip_address_range = ip_security_restriction.value.ip_address_range
          name             = ip_security_restriction.value.name
          description      = ip_security_restriction.value.description
        }
      }
    }
  }

  # Managed identity
  dynamic "identity" {
    for_each = var.enable_managed_identity ? [1] : []
    
    content {
      type         = var.identity_type
      identity_ids = var.identity_ids
    }
  }

  # Dapr configuration
  dynamic "dapr" {
    for_each = var.enable_dapr ? [var.dapr_config] : []
    
    content {
      app_id       = dapr.value.app_id
      app_port     = dapr.value.app_port
      app_protocol = dapr.value.app_protocol
    }
  }

  # Registry credentials
  dynamic "registry" {
    for_each = var.registry_credentials
    
    content {
      server               = registry.value.server
      username             = registry.value.username
      password_secret_name = registry.value.password_secret_name
      identity             = registry.value.identity
    }
  }

  tags = merge(var.tags, {
    Purpose = "Application hosting"
    Type    = "Container App"
  })
}

# Local variables
locals {
  container_app_name = "ca-${var.app_name}-${var.environment}-${var.location_short}"
}
