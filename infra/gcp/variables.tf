variable "project_id" {
  type        = string
  description = "Existing billed GCP project ID; no placeholder account or project is assumed."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Supply a real GCP project ID (6-30 lowercase characters)."
  }
}
variable "region" {
  type    = string
  default = "asia-northeast3"
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Use a GCP region, not a zone."
  }
}
variable "name" {
  type    = string
  default = "oneaction"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}[a-z0-9]$", var.name))
    error_message = "Use a 2-16 character lowercase resource name."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,5}$", var.environment))
    error_message = "Use a 1-6 character environment name."
  }
}
variable "owner" {
  type    = string
  default = "platform"

}
variable "allow_public_control_plane" {
  type        = bool
  default     = false
  description = "Explicit test-environment opt-in to broad GKE administrator network access; authentication still applies."
}
variable "public_access_cidrs" {
  type        = set(string)
  description = "Explicit administrator IPv4 egress allowlist."
  validation {
    condition     = length(var.public_access_cidrs) > 0 && alltrue([for cidr in var.public_access_cidrs : can(cidrnetmask(cidr)) && (var.allow_public_control_plane || try(tonumber(split("/", cidr)[1]) >= 24, false))])
    error_message = "Supply at least one IPv4 /24 or narrower CIDR; broader access requires explicit allow_public_control_plane test opt-in."
  }
}
variable "admin_members" {
  type        = set(string)
  default     = []
  description = "Optional existing user/group/serviceAccount IAM members granted GKE cluster administration."
  validation {
    condition     = alltrue([for member in var.admin_members : can(regex("^(user|group|serviceAccount):[^ ]+@[^ ]+$", member))])
    error_message = "Use explicit user:, group:, or serviceAccount: identities."
  }
}
variable "node_machine_type" {
  type    = string
  default = "e2-medium"

}
variable "node_count_per_zone" {
  type    = number
  default = 1
  validation {
    condition     = var.node_count_per_zone >= 1 && floor(var.node_count_per_zone) == var.node_count_per_zone
    error_message = "Node count per zone must be a positive integer."
  }
}
variable "node_zone_suffixes" {
  type    = set(string)
  default = ["a", "b", "c"]
  validation {
    condition     = length(var.node_zone_suffixes) >= 2 && alltrue([for zone in var.node_zone_suffixes : can(regex("^[a-z]$", zone))])
    error_message = "Choose at least two valid zone suffixes in the selected region."
  }
}
variable "db_tier" {
  type    = string
  default = "db-custom-1-3840"

}
variable "db_password" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = "Supply through TF_VAR_db_password; never write into tfvars. Publish the same value to Secret Manager outside Terraform."
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "The database password must contain at least 16 characters."
  }
}
variable "db_password_version" {
  type    = number
  default = 1
  validation {
    condition     = var.db_password_version >= 1 && floor(var.db_password_version) == var.db_password_version
    error_message = "Increment this positive integer when rotating the write-only password."
  }
}
variable "db_high_availability" {
  type    = bool
  default = false

}
variable "deletion_protection" {
  type    = bool
  default = true

}
variable "domain_name" {
  type        = string
  default     = ""
  description = "Optional real application FQDN, without a trailing dot."
  validation {
    condition     = var.domain_name == "" || can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "Use an application FQDN without wildcard or trailing dot, or leave empty."
  }
}
variable "dns_zone_name" {
  type        = string
  default     = ""
  description = "Existing Cloud DNS public managed zone name; empty creates a new public zone for dns_domain."

}
variable "dns_domain" {
  type        = string
  default     = ""
  description = "Parent public DNS zone FQDN; empty uses domain_name. Delegate the returned name servers."
  validation {
    condition     = var.dns_domain == "" || can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.dns_domain))
    error_message = "Use a DNS zone domain without a trailing dot."
  }
}
variable "notification_email" {
  type    = string
  default = ""
  validation {
    condition     = var.notification_email == "" || can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.notification_email))
    error_message = "Use a valid alert email, or empty to provision policies without a delivery channel."
  }
}
variable "enable_kafka" {
  type    = bool
  default = true

}
variable "kafka_vcpu_count" {
  type    = number
  default = 3
  validation {
    condition     = var.kafka_vcpu_count >= 3 && floor(var.kafka_vcpu_count) == var.kafka_vcpu_count
    error_message = "Managed Kafka requires at least three vCPUs."
  }
}
variable "kafka_memory_gib" {
  type    = number
  default = 3
  validation {
    condition     = floor(var.kafka_memory_gib) == var.kafka_memory_gib && var.kafka_memory_gib >= var.kafka_vcpu_count && var.kafka_memory_gib <= var.kafka_vcpu_count * 8
    error_message = "Use an integer Kafka memory size between 1 and 8 GiB per vCPU."
  }
}

variable "enable_tailscale" {
  description = "Enable the private on-prem subnet router. Required for the full AWS-equivalent scope; false preserves the original draft inputs."
  type        = bool
  default     = false
}
variable "tailscale_auth_key_secret_id" {
  description = "Existing Secret Manager secret ID in project_id; never the auth key value."
  type        = string
  default     = ""
  validation {
    condition     = !var.enable_tailscale || can(regex("^[a-zA-Z0-9_-]{1,255}$", var.tailscale_auth_key_secret_id))
    error_message = "Full deployment needs the existing Tailscale auth-key secret ID."
  }
}
variable "tailscale_machine_type" {
  description = "Private router machine type; compare with the actual AWS t4g.nano router before applying."
  type        = string
  default     = "e2-micro"
}
variable "require_full_scope" {
  description = "Reject an incomplete full-scope deployment rather than silently omitting AWS counterparts."
  type        = bool
  default     = false
  validation {
    condition     = !var.require_full_scope || (var.enable_kafka && var.enable_tailscale && var.domain_name != "" && var.notification_email != "")
    error_message = "Full scope requires Kafka, Tailscale, a real domain, and an alert email. Prepare the inputs before applying."
  }
}

variable "kafka_bootstrap_brokers" {
  description = "Actual Kafka bootstrapAddress including port, queried after creation; never inferred from the cluster ID."
  type        = string
  default     = null
  validation {
    condition     = var.kafka_bootstrap_brokers == null ? true : can(regex("^[a-zA-Z0-9.-]+:9092$", var.kafka_bootstrap_brokers))
    error_message = "Use the actual Kafka bootstrap hostname followed by :9092."
  }
}

variable "db_enable_proxy_public_ip" {
  type        = bool
  default     = false
  description = "Opt in to AWS-to-Cloud SQL Auth Proxy connectivity without a cross-cloud private route."
}
