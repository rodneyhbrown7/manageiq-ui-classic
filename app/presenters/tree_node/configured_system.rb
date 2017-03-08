module TreeNode
  class ConfiguredSystem < Node
    set_attribute(:title, &:hostname)
    set_attribute(:tooltip) { _("Configured System: %{hostname}") % {:hostname => @object.hostname} }
  end
end
