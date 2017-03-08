class TreeBuilderAlertProfile < TreeBuilder
  has_kids_for MiqAlertSet, [:x_get_tree_ap_kids]

  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def alert_profile_kinds
    MiqAlert.base_tables.sort_by { |a| ui_lookup(:model => a) }
  end

  # level 0 - root
  def root_options
    {
      :title   => t = _("All Alert Profiles"),
      :tooltip => t
    }
  end

  # level 1 - * alert profiles
  def x_get_tree_roots(count_only, _options)
    objects = alert_profile_kinds.map do |db|
      # Set alert profile folder nodes to open so we pre-load all children
      open_node("xx-#{db}")
      text = _("%{model} Alert Profiles") % {:model => ui_lookup(:model => db)}
      graphic = case db
                when 'EmsCluster'
                  {:icon => 'pficon pficon-cluster'}
                when 'Storage'
                  {:icon => 'fa fa-database'}
                when 'Host'
                  {:icon => 'pficon pficon-screen'}
                when 'MiddlewareServer'
                  {:image => 'svg/vendor-wildfly.svg'}
                when 'ContainerNode'
                  {:icon => 'pficon pficon-container-node'}
                when 'ExtManagementSystem'
                  {:icon => 'pficon pficon-server'}
                when 'MiqServer'
                  {:icon => 'pficon pficon-server'}
                when 'Vm'
                  {:icon => 'pficon pficon-virtual-machine'}
                end
      {:id => db, :text => text, :tip => text}.merge(graphic)
    end

    count_only_or_objects(count_only, objects)
  end

  # level 2 - alert profiles
  def x_get_tree_custom_kids(parent, count_only, options)
    assert_type(options[:type], :alert_profile)

    objects = MiqAlertSet.where(:mode => parent[:id].split('-'))

    count_only_or_objects(count_only, objects, :description)
  end

  # level 3 - alerts
  def x_get_tree_ap_kids(parent, count_only)
    count_only_or_objects(count_only,
                          parent.miq_alerts,
                          :description)
  end
end
