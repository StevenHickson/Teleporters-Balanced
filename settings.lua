data:extend({
  {
    type = "bool-setting",
    name = "teleporters-planet-lock",
    setting_type = "startup",
    default_value = true,
  },
  {
    type = "bool-setting",
    name = "teleporters-require-aquilo",
    setting_type = "startup",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "teleporters-same-surface-only",
    setting_type = "startup",
    default_value = false,
  },
  {
    type = "string-setting",
    name = "teleporters-inventory-restriction",
    setting_type = "runtime-global",
    default_value = "none",
    allowed_values = { "none", "inventory", "inventory-ammo" }
  },
  {
    type = "string-setting",
    name = "teleporters-inventory-restriction-interplanetary",
    setting_type = "runtime-global",
    default_value = "inventory-ammo",
    allowed_values = { "none", "science", "inventory", "inventory-ammo" }
  },
  {
    type = "bool-setting",
    name = "teleporters-weight-restriction",
    setting_type = "runtime-global",
    default_value = true,
  }
})
