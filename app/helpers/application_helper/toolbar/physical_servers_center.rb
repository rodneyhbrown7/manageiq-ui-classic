class ApplicationHelper::Toolbar::EmsPhysicalInfrasCenter < ApplicationHelper::Toolbar::Basic
  button_group('physical_server_vmdb', [
    select(
      :physical_server_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :physical_server_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to the selected Infrastructure Providers'),
          N_('Refresh Relationships and Power States'),
          :url_parms => "main_div",
          :confirm   => N_("Refresh relationships and power states for all items related to the selected Infrastructure Providers?"),
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :physical_server_discover,
          'fa fa-search fa-lg',
          t = N_('Discover Infrastructure Providers'),
          t,
          :url       => "/discover",
          :url_parms => "?discover_type=ems"),
        separator,
        button(
          :physical_server_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Infrastructure Provider'),
          t,
          :url => "/new"),
        button(
          :physical_server_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Infrastructure Provider to edit'),
          N_('Edit Selected Infrastructure Providers'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :physical_server_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Infrastructure Providers'),
          N_('Remove Infrastructure Providers'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Infrastructure Providers and ALL of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('physical_server_policy', [
    select(
      :physical_server_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :physical_server_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for the selected Physical Infrastructure Providers'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :physical_server_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Physical Infrastructure Providers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :physical_server_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for these Physical Infra Managers'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+")
      ]
    ),
  ])
  button_group('physical_server_authentication', [
    select(
      :physical_server_authentication_choice,
      'fa fa-lock fa-lg',
      t = N_('Authentication'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :physical_server_recheck_auth_status,
          'fa fa-search fa-lg',
          N_('Re-check Authentication Status for the selected Physical Infrastructure Providers'),
          N_('Re-check Authentication Status'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
