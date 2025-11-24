# Talos Image Builder Module - Outputs

output "build_complete" {
  description = "Indicates that the build process has completed"
  value       = null_resource.build_images.id
}
