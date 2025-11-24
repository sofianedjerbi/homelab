# Automated Talos Image Builder with Caching
# The Packer script itself checks for existing snapshots and skips if found

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49.0"
    }
  }
}

# Clone or update hcloud-talos repo
resource "null_resource" "clone_repo" {
  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -d "${var.packer_cache_dir}" ]; then
        echo "Cloning hcloud-talos repository..."
        git clone https://github.com/hcloud-talos/terraform-hcloud-talos.git ${var.packer_cache_dir}
      else
        echo "Using cached hcloud-talos repository at ${var.packer_cache_dir}"
      fi
    EOT
  }
}

# Build Talos images with Packer
# The create.sh script checks if snapshots already exist and skips if found
resource "null_resource" "build_images" {
  depends_on = [null_resource.clone_repo]

  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e  # Exit immediately if any command fails

      # Check if Packer is installed
      if ! command -v packer &> /dev/null; then
        echo "ERROR: Packer is not installed!"
        echo "Run 'devbox install' to install all required tools."
        exit 1
      fi

      cd ${var.packer_cache_dir}/_packer

      echo "Checking for Talos ${var.talos_version} images..."
      echo "If images don't exist, this will take ~10 minutes to build."

      # Set version in environment for Packer
      export TALOS_VERSION="${var.talos_version}"

      # Build images (script checks for existing snapshots first)
      if ! echo "${var.talos_version}" | ./create.sh; then
        echo "ERROR: Packer build failed!"
        exit 1
      fi

      echo "Talos images ready!"
    EOT

    environment = {
      HCLOUD_TOKEN = var.hcloud_token
    }

    # Fail the resource if provisioner fails (default, but explicit)
    on_failure = fail
  }
}
