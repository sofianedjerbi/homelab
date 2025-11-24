# Talos Kubernetes on Hetzner Cloud - Terragrunt

Fully automated Talos Kubernetes deployment using the mature [hcloud-talos](https://github.com/hcloud-talos/terraform-hcloud-talos) module.

## Features

✅ **100% Automated** - Just `terragrunt apply` (includes Packer image building!)
✅ **Smart Caching** - Talos images built once, reused forever
✅ **Production Ready** - Uses proven, maintained module
✅ **Secure by Default** - Firewall, private networks, encrypted networking
✅ **Fully Declarative** - Infrastructure as Code with Terragrunt
✅ **Multi-Cluster** - Easy to manage multiple environments
✅ **DRY Principle** - All versions in `devbox.json`, no redundancy!

## Versions

**Using Talos v1.12.0-beta.0** (fixes gcr.io registry issue from v1.11)

All versions centralized in `devbox.json` - change once, apply everywhere!

## Structure

```
terraform/
├── terragrunt.hcl              # Root config (TF Cloud, providers, defaults)
├── _modules/
│   └── talos-images/           # Automated Packer builder with caching
├── _dependencies/
│   └── talos-images/           # Shared dependency: ensures images exist
└── clusters/
    ├── lab-01/                 # Single-node learning cluster
    │   └── terragrunt.hcl
    └── lab-02/                 # Multi-node HA cluster
        └── terragrunt.hcl
```

## Prerequisites

### 1. Install Tools (via devbox)

Already installed via `devbox.json`:
- terraform
- terragrunt
- kubectl
- talosctl
- helm

### 2. Set Up Environment

```bash
# Copy example
cp ../.env.example ../.env

# Edit .env with your values:
# - TF_CLOUD_ORGANIZATION (from https://app.terraform.io)
# - TF_API_TOKEN (from https://app.terraform.io/app/settings/tokens)
# - HCLOUD_TOKEN (from https://console.hetzner.cloud/)

# Load environment
direnv allow
```

### 3. Terraform Cloud Setup

1. Create account at https://app.terraform.io
2. Create organization
3. Generate API token
4. Add to `.env`

Workspaces are created automatically on first `terragrunt init`.

### 4. Hetzner Cloud Setup

1. Login to https://console.hetzner.cloud/
2. Create or select project
3. Go to Security → API Tokens
4. Generate new token with Read & Write permissions
5. Add to `.env` as `HCLOUD_TOKEN`

### 5. Talos Images (FULLY AUTOMATED!)

**No manual steps needed!** Terragrunt automatically:
1. Checks if Talos snapshots exist for your version
2. If missing, builds them with Packer (~10 min on first run)
3. Caches the build repo at `~/.cache/hcloud-talos`
4. Reuses existing snapshots on subsequent runs

**First deployment**: Takes ~15 minutes (10 min Packer + 5 min cluster)
**Subsequent deployments**: Takes ~5 minutes (uses cached snapshots)

## Usage

### Deploy lab-01 (Single-Node Cluster)

```bash
cd terraform/clusters/lab-01

# Initialize (creates TF Cloud workspace)
terragrunt init

# Review plan (shows Packer build if images missing)
terragrunt plan

# Deploy everything (FULLY AUTOMATED!)
# First run: ~15 min (builds Talos images + deploys cluster)
# Subsequent runs: ~5 min (uses cached images)
terragrunt apply

# Get credentials
terragrunt output -raw talosconfig > talosconfig
terragrunt output -raw kubeconfig > kubeconfig

# Verify cluster
export TALOSCONFIG=$PWD/talosconfig
export KUBECONFIG=$PWD/kubeconfig
talosctl health
kubectl get nodes
kubectl get pods -A
```

### Deploy lab-02 (Multi-Node HA Cluster)

```bash
cd terraform/clusters/lab-02
terragrunt apply
```

### Destroy Cluster

```bash
cd terraform/clusters/lab-01
terragrunt destroy
```

## What Gets Created

### Infrastructure (via hcloud-talos module):

- **Servers**: Control plane(s) and workers (if configured)
- **Private Network**: Internal node-to-node communication
- **Firewall**: Restricts access to your IP (if `firewall_use_current_ip = true`)
- **Talos OS**: Immutable, secure Kubernetes OS
- **Kubernetes**: Fully configured cluster

### Automatically Installed:

- **Cilium**: Modern CNI with network policies
- **Hcloud Cloud Controller Manager**: Native Hetzner integration
- **Talos Cloud Controller Manager**: Node initialization and CSR approval
- **CoreDNS**: DNS service
- **Metrics Server**: Resource metrics

## Configuration Options

### lab-01 (Default Single-Node)

```hcl
control_plane_count       = 1
control_plane_server_type = "cx22"  # €5.83/month
worker_count              = 0
allow_scheduling_on_control_planes = true  # Required for single-node
```

**Cost**: ~€6/month

### lab-02 (Example HA Setup)

```hcl
control_plane_count       = 3       # HA control plane
control_plane_server_type = "cax11" # ARM, €3.79/month each
worker_count              = 2
worker_server_type        = "cax11"
```

**Cost**: ~€19/month (3 control + 2 workers)

### Common Settings

**All versions are defined in `devbox.json` (DRY principle!):**

```json
{
  "env": {
    "TALOS_VERSION": "v1.12.0-beta.0",
    "KUBERNETES_VERSION": "1.34.1",
    "CILIUM_VERSION": "1.16.4"
  }
}
```

Terragrunt automatically reads these environment variables - **no redundancy!**

Other settings in `terraform/terragrunt.hcl`:
```hcl
firewall_use_current_ip = true   # Auto-allow your IP
```

## Module Documentation

Full module documentation: https://registry.terraform.io/modules/hcloud-talos/talos/hcloud

### Key Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `cluster_name` | Cluster identifier | - |
| `datacenter_name` | Hetzner datacenter | - |
| `control_plane_count` | Number of control planes | 1 |
| `control_plane_server_type` | Server type for control planes | - |
| `worker_count` | Number of workers | 0 |
| `worker_server_type` | Server type for workers | - |
| `allow_scheduling_on_control_planes` | Schedule pods on control plane | false |
| `firewall_use_current_ip` | Auto-allow current IP | true |

### Key Outputs

| Output | Description |
|--------|-------------|
| `talosconfig` | Talos client configuration |
| `kubeconfig` | Kubernetes client configuration |
| `cluster_name` | Cluster name |

## Troubleshooting

### Packer Build Automation

**How it works:**
1. Terragrunt checks Hetzner for existing Talos snapshots with matching version
2. If found → Uses cached snapshots (instant)
3. If not found → Automatically runs Packer to build them (~10 min)
4. Build repo cached at `~/.cache/hcloud-talos` (reused across versions)

**Force rebuild:**
```bash
# Delete snapshots in Hetzner Console or via CLI
hcloud image list | grep talos
hcloud image delete <snapshot-id>

# Next apply will rebuild
terragrunt apply
```

**Clear build cache:**
```bash
rm -rf ~/.cache/hcloud-talos
```

### "Current IP could not be determined"

**Solution**: Set `firewall_use_current_ip = false` and manually provide IPs:

```hcl
firewall_use_current_ip    = false
firewall_kube_api_source   = ["your.public.ip.address/32"]
firewall_talos_api_source  = ["your.public.ip.address/32"]
```

### "Terraform Cloud workspace not created"

**Solution**: Run `terragrunt init` - it creates workspaces automatically

### Version Compatibility Issues

**Important**: Ensure version compatibility:
- Talos version (Packer build) = `talos_version` in Terragrunt
- Kubernetes version must be compatible with Talos version
- Cilium version must be compatible with Kubernetes version

Check compatibility: https://www.talos.dev/latest/introduction/support-matrix/

## Cleanup

### Delete a cluster:
```bash
cd terraform/clusters/lab-01
terragrunt destroy
```

### Remove Talos snapshots (optional):
```bash
# List snapshots
hcloud image list | grep talos

# Delete snapshot
hcloud image delete <snapshot-id>
```

## Cost Optimization

**Single-Node Learning**: Use `cx22` (~€6/month)
**Multi-Node Learning**: Use ARM `cax11` (~€4/month per node)
**Remember**: Destroy clusters when not in use with `terragrunt destroy`

## Best Practices

1. **Version Pin**: Use specific module versions (not `latest`)
2. **Separate Workspaces**: Each cluster = one TF Cloud workspace
3. **Tag Resources**: Automatic via module (cluster name, etc.)
4. **Destroy Unused**: Save money - destroy clusters when learning is done
5. **Backup Configs**: Commit your `terragrunt.hcl` files to git (NOT `.env`!)

## Next Steps

After cluster is running:
1. Deploy applications with Helm
2. Set up monitoring (Prometheus/Grafana)
3. Configure ingress controller
4. Set up cert-manager for TLS
5. Explore Talos features (upgrades, backups, etc.)

## Resources

- [Talos Documentation](https://www.talos.dev/)
- [hcloud-talos Module](https://github.com/hcloud-talos/terraform-hcloud-talos)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Terragrunt Docs](https://terragrunt.gruntwork.io/)
