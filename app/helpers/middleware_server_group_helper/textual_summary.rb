module MiddlewareServerGroupHelper::TextualSummary
  def textual_group_properties
    TextualGroup.new(_("Properties"), %i(name profile nativeid))
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    TextualGroup.new(_("Relationships"), %i(middleware_domain middleware_servers))
  end

  def textual_profile
    @record.profile
  end
end
