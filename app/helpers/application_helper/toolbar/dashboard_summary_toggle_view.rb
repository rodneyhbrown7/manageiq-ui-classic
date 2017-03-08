class ApplicationHelper::Toolbar::DashboardSummaryToggleView < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_dashboard', [
    twostate(
      :view_dashboard,
      'fa fa-tachometer fa-1xplus',
      N_('Dashboard View'),
      nil,
      :url       => "/",
      :url_parms => "?display=dashboard",
      :klass     => ApplicationHelper::Button::ViewDashboard),
    twostate(
      :view_summary,
      'fa fa-th-list',
      N_('Summary View'),
      nil,
      :url       => "/",
      :url_parms => "?display=main",
      :klass     => ApplicationHelper::Button::ViewSummary
    ),
    twostate(
      :view_topology,
      'fa pficon-topology',
      N_('Topology View'),
      nil,
      :url       => "/",
      :url_parms => "?display=topology",
      :klass     => ApplicationHelper::Button::TopologyFeatureButton)
  ])
end
