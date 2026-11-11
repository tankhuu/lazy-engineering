# Identical in every env: the unit's directory name selects _envcommon/<unit>.hcl,
# values come from ../env.hcl. Change behaviour in _envcommon, not here.

include "backend" {
  path = find_in_parent_folders("backend.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("common.hcl"))}/_envcommon/${basename(get_terragrunt_dir())}.hcl"
  expose = true
}
