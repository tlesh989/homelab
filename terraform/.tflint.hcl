tflint {
  required_version = ">= 0.50"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "proxmox" {
  enabled = true
  version = "0.7.0"
  source  = "github.com/bpg/tflint-ruleset-proxmox"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"  # Explicit format for consistency
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = false  # Modules may expose vars for future use
}

rule "terraform_comment_syntax" {
  enabled = true  # Enforce consistent comment style (# vs //)
}

rule "terraform_module_pinned_source" {
  enabled = true  # Ensure module sources use version constraints
  style   = "semver"  # For registry modules
}

rule "terraform_module_version" {
  enabled = true  # Check module versions are specified (important for stability)
}

# rule "terraform_standard_module_structure" {
#   enabled = true  # Enforce main.tf, variables.tf, outputs.tf structure
# }

rule "terraform_workspace_remote" {
  enabled = true  # Ensure remote backend is configured (HCP Terraform)
}

rule "terraform_unused_required_providers" {
  enabled = true  # Catch unused provider declarations
}
