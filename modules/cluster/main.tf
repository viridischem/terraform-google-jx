// ----------------------------------------------------------------------------
// Create and configure the Kubernetes cluster
//
// https://www.terraform.io/docs/providers/google/r/container_cluster.html
// ----------------------------------------------------------------------------
resource "google_container_cluster" "jx_cluster" {
  provider                = google-beta
  name                    = var.cluster_name
  description             = "jenkins-x cluster"
  location                = var.cluster_location
  enable_kubernetes_alpha = var.enable_kubernetes_alpha
  enable_legacy_abac      = var.enable_legacy_abac
  initial_node_count      = var.min_node_count
  logging_service         = var.logging_service
  monitoring_service      = var.monitoring_service

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    identity_namespace = "${var.gcp_project}.svc.id.goog"
  }

  network = var.network
  subnetwork = var.subnetwork
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name = "${var.subnetwork}-pods"
    services_secondary_range_name = "${var.subnetwork}-services"
  }

  resource_labels = var.resource_labels

  cluster_autoscaling {
    enabled = true

    resource_limits {
      resource_type = "cpu"
      minimum       = ceil(var.min_node_count * var.machine_types_cpu[var.node_machine_type])
      maximum       = ceil(var.max_node_count * var.machine_types_cpu[var.node_machine_type])
    }

    resource_limits {
      resource_type = "memory"
      minimum       = ceil(var.min_node_count * var.machine_types_memory[var.node_machine_type])
      maximum       = ceil(var.max_node_count * var.machine_types_memory[var.node_machine_type])
    }
  }

  addons_config {
    http_load_balancing {
      disabled = true
    }

    horizontal_pod_autoscaling {
      disabled = true
    }

    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled = true
  }

  node_config {
    preemptible  = var.node_preemptible
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.full_control",
      "https://www.googleapis.com/auth/service.management",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
  }
}

// ----------------------------------------------------------------------------
// Add main Jenkins X Kubernetes namespace
// 
// https://www.terraform.io/docs/providers/kubernetes/r/namespace.html
// ----------------------------------------------------------------------------
resource "kubernetes_namespace" "jenkins_x_namespace" {
  metadata {
    name = var.jenkins_x_namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }

  depends_on = [
    google_container_cluster.jx_cluster
  ]
}
