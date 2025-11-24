# Talos Images Dependency
# Automatically builds Talos snapshots if they don't exist
# Uses caching - only builds once per version!

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../_modules/talos-images"
}

inputs = {
  talos_version = get_env("TALOS_VERSION")
  hcloud_token  = get_env("HCLOUD_TOKEN")

  # Cache directory (persists across runs)
  packer_cache_dir = "${get_env("HOME")}/.cache/hcloud-talos"
}
