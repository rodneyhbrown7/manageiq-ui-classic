class FlavorController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include Mixins::GenericButtonMixin
  include Mixins::GenericSessionMixin

  def self.display_methods
    %w(instances)
  end

  private

  def textual_group_list
    [%i(properties relationships), %i(tags)]
  end
  helper_method :textual_group_list

  menu_section :clo
end
