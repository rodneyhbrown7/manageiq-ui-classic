require "rexml/document"
class MiqAeClassController < ApplicationController
  include MiqAeClassHelper
  include AutomateTreeHelper
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  MIQ_AE_COPY_ACTIONS = %w(miq_ae_class_copy miq_ae_instance_copy miq_ae_method_copy).freeze

  # GET /automation_classes
  # GET /automation_classes.xml
  def index
    redirect_to :action => 'explorer'
  end

  def change_tab
    # resetting flash array so messages don't get displayed when tab is changed
    @flash_array = []
    @explorer = true
    @record = @ae_class = MiqAeClass.find(from_cid(x_node.split('-').last))
    @sb[:active_tab] = params[:tab_id]
    render :update do |page|
      page << javascript_prologue
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << javascript_reload_toolbars
      page << "miqSparkle(false);"
    end
  end

  AE_X_BUTTON_ALLOWED_ACTIONS = {
    'instance_fields_edit'        => :edit_instance,
    'method_inputs_edit'          => :edit_mehod,
    'miq_ae_class_copy'           => :copy_objects,
    'miq_ae_class_edit'           => :edit_class,
    'miq_ae_class_delete'         => :deleteclasses,
    'miq_ae_class_new'            => :new,
    'miq_ae_domain_delete'        => :delete_domain,
    'miq_ae_domain_edit'          => :edit_domain,
    'miq_ae_domain_lock'          => :domain_lock,
    'miq_ae_domain_unlock'        => :domain_unlock,
    'miq_ae_git_refresh'          => :git_refresh,
    'miq_ae_domain_new'           => :new_domain,
    'miq_ae_domain_priority_edit' => :domains_priority_edit,
    'miq_ae_field_edit'           => :edit_fields,
    'miq_ae_field_seq'            => :fields_seq_edit,
    'miq_ae_instance_copy'        => :copy_objects,
    'miq_ae_instance_delete'      => :deleteinstances,
    'miq_ae_instance_edit'        => :edit_instance,
    'miq_ae_instance_new'         => :new_instance,
    'miq_ae_item_edit'            => :edit_item,
    'miq_ae_method_copy'          => :copy_objects,
    'miq_ae_method_delete'        => :deletemethods,
    'miq_ae_method_edit'          => :edit_method,
    'miq_ae_method_new'           => :new_method,
    'miq_ae_namespace_delete'     => :delete_ns,
    'miq_ae_namespace_edit'       => :edit_ns,
    'miq_ae_namespace_new'        => :new_ns,
  }.freeze

  def x_button
    generic_x_button(AE_X_BUTTON_ALLOWED_ACTIONS)
  end

  def explorer
    @trees = []
    @sb[:action] = nil
    @explorer = true
    # don't need right bottom cell
    @breadcrumbs = []
    bc_name = _("Explorer")
    bc_name += _(" (filtered)") if @filters && (!@filters[:tags].blank? || !@filters[:cats].blank?)
    drop_breadcrumb(:name => bc_name, :url => "/miq_ae_class/explorer")
    @lastaction = "replace_right_cell"

    build_accordions_and_trees

    @right_cell_text ||= _("Datastore")
    render :layout => "application"
  end

  def set_right_cell_text(id, rec = nil)
    nodes = id.split('-')
    case nodes[0]
    when "root"
      txt = _("Datastore")
      @sb[:namespace_path] = ""
    when "aec"
      txt = _('Automate Class')
      @sb[:namespace_path] = rec.fqname
    when "aei"
      txt = _('Automate Instance')
      updated_by = rec.updated_by ? _(" by %{user}") % {:user => rec.updated_by} : ""
      @sb[:namespace_path] = rec.fqname
      @right_cell_text = _("%{model} [%{name} - Updated %{time}%{update}]") % {
        :model  => txt,
        :name   => get_rec_name(rec),
        :time   => format_timezone(rec.updated_on, Time.zone, "gtl"),
        :update => updated_by
      }
    when "aem"
      txt = _('Automate Method')
      updated_by = rec.updated_by ? _(" by %{user}") % {:user => rec.updated_by} : ""
      @sb[:namespace_path] = rec.fqname
      @right_cell_text = _("%{model} [%{name} - Updated %{time}%{update}]") % {
        :model  => txt,
        :name   => get_rec_name(rec),
        :time   => format_timezone(rec.updated_on, Time.zone, "gtl"),
        :update => updated_by
      }
    when "aen"
      txt = rec.domain? ? _('Automate Domain') : _('Automate Namespace')
      @sb[:namespace_path] = rec.fqname
    end
    @sb[:namespace_path].gsub!(%r{\/}, " / ") if @sb[:namespace_path]
    @right_cell_text = "#{txt} #{_("\"%s\"") % get_rec_name(rec)}" unless %w(root aei aem).include?(nodes[0])
  end

  def expand_toggle
    render :update do |page|
      page << javascript_prologue
      if @sb[:squash_state]
        @sb[:squash_state] = false
        page << javascript_show("inputs_div")
        page << "$('#exp_collapse_img i').attr('class','fa fa-angle-up fa-lg')"
        page << "$('#exp_collapse_img').prop('title', 'Hide Input Parameters');"
        page << "$('#exp_collapse_img').prop('alt', 'Hide Input Parameters');"
      else
        @sb[:squash_state] = true
        page << javascript_hide("inputs_div")
        page << "$('#exp_collapse_img i').attr('class','fa fa-angle-down fa-lg')"
        page << "$('#exp_collapse_img').prop('title', 'Show Input Parameters');"
        page << "$('#exp_collapse_img').prop('alt', 'Show Input Parameters');"
      end
    end
  end

  def get_node_info(node, _show_list = true)
    id = valid_active_node(node).split('-')
    @sb[:row_selected] = nil if params[:action] == "tree_select"
    case id[0]
    when "aec"
      get_class_node_info(id)
    when "aei"
      get_instance_node_info(id)
    when "aem"
      get_method_node_info(id)
    when "aen"
      @record = MiqAeNamespace.find(from_cid(id[1]))
      # need to set record as Domain record if it's a domain, editable_domains, enabled_domains,
      # visible domains methods returns list of Domains, need this for toolbars to hide/disable correct records.
      @record = MiqAeDomain.find(from_cid(id[1])) if @record.domain?
      @version_message = domain_version_message(@record) if @record.domain?
      if @record.nil?
        set_root_node
      else
        @records = []
        # Add Namespaces under a namespace
        details = @record.ae_namespaces
        @records += details.sort_by { |d| [d.display_name.to_s, d.name.to_s] }
        # Add classes under a namespace
        details_cls = @record.ae_classes
        unless details_cls.nil?
          @records += details_cls.sort_by { |d| [d.display_name.to_s, d.name.to_s] }
        end
        @combo_xml = build_type_options
        @dtype_combo_xml = build_dtype_options
        @sb[:active_tab] = "details"
        set_right_cell_text(x_node, @record)
      end
    else
      @grid_data = User.current_tenant.visible_domains
      add_all_domains_version_message(@grid_data)
      @record = nil
      @right_cell_text = _("Datastore")
      @sb[:active_tab] = "namespaces"
      set_right_cell_text(x_node)
    end
    x_history_add_item(:id => x_node, :text => @right_cell_text)
  end

  def domain_version_message(domain)
    version = domain.version
    available_version = domain.available_version
    return if version.nil? || available_version.nil?
    if version != available_version
      _("%{name} domain: Current version - %{version}, Available version - %{available_version}") %
        {:name => domain.name, :version => version, :available_version => available_version}
    end
  end

  def add_all_domains_version_message(domains)
    @version_messages = domains.collect { |dom| domain_version_message(dom) }.compact
  end

  # Tree node selected in explorer
  def tree_select
    @explorer = true
    @lastaction = "explorer"
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    @sb[:action] = nil
    replace_right_cell
  end

  # Check for parent nodes missing from ae tree and return them if any
  def open_parent_nodes(record)
    nodes = record.fqname.split("/")
    parents = []
    nodes.each_with_index do |_, i|
      if i == nodes.length - 1
        selected_node = x_node.split("-")
        parents.push(record.ae_class) if %w(aei aem).include?(selected_node[0])
        self.x_node = "#{selected_node[0]}-#{to_cid(record.id)}"
        parents.push(record)
      else
        ns = MiqAeNamespace.find_by(:fqname => nodes[0..i].join("/"))
        parents.push(ns) if ns
      end
    end
    build_and_add_nodes(parents)
  end

  def build_and_add_nodes(parents)
    existing_node = find_existing_node(parents)
    return nil if existing_node.nil?
    children = tree_add_child_nodes(existing_node)
    # set x_node after building tree nodes so parent node of new nodes can be selected in the tree.
    unless params[:action] == "x_show"
      self.x_node = if @record.kind_of?(MiqAeClass)
                      "aen-#{to_cid(@record.namespace_id)}"
                    else
                      "aec-#{to_cid(@record.class_id)}"
                    end
    end
    {:key => existing_node, :nodes => children}
  end

  def find_existing_node(parents)
    existing_node = nil
    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    unless parents.empty? || # Skip if no parents or parent already open
           x_tree[:open_nodes].include?(x_build_node_id(parents.last))
      parents.reverse_each do |p|
        p_node = x_build_node_id(p)
        if x_tree[:open_nodes].include?(p_node)
          return p_node
        else
          x_tree[:open_nodes].push(p_node)
          existing_node = p_node
        end
      end
    end
    existing_node
  end

  def replace_right_cell(options = {})
    @explorer = true
    replace_trees = options[:replace_trees]

    # FIXME: is the following line needed?
    # replace_trees = @replace_trees if @replace_trees  #get_node_info might set this

    nodes = x_node.split('-')

    @in_a_form = @in_a_form_fields = @in_a_form_props = false if params[:button] == "cancel" ||
                                                                 (%w(save add).include?(params[:button]) && replace_trees)
    add_nodes = open_parent_nodes(@record) if params[:button] == "copy" ||
                                              params[:action] == "x_show"
    get_node_info(x_node) if !@in_a_form && !@angular_form && @button != "reset"

    c_tb = build_toolbar(center_toolbar_filename) unless @in_a_form
    h_tb = build_toolbar("x_history_tb")

    presenter = ExplorerPresenter.new(
      :active_tree     => x_active_tree,
      :right_cell_text => @right_cell_text,
      :remove_nodes    => add_nodes, # remove any existing nodes before adding child nodes to avoid duplication
      :add_nodes       => add_nodes,
    )

    reload_trees_by_presenter(presenter, [build_ae_tree]) unless replace_trees.blank?

    if @sb[:action] == "miq_ae_field_seq"
      presenter.update(:class_fields_div, r[:partial => "fields_seq_form"])

    elsif @sb[:action] == "miq_ae_domain_priority_edit"
      presenter.update(:ns_list_div, r[:partial => "domains_priority_form"])

    elsif MIQ_AE_COPY_ACTIONS.include?(@sb[:action])
      presenter.update(:main_div, r[:partial => "copy_objects_form"])

    else
      if @sb[:action] == "miq_ae_class_edit"
        @sb[:active_tab] = 'props'
      else
        @sb[:active_tab] ||= 'instances'
      end
      presenter.update(:main_div, r[:partial => 'all_tabs'])
    end

    presenter.replace('flash_msg_div', r[:partial => "layouts/flash_msg"]) if @flash_array

    if @in_a_form && !@angular_form
      action_url = create_action_url(nodes.first)
      # incase it was hidden for summary screen, and incase there were no records on show_list
      presenter.show(:paging_div, :form_buttons_div)
      presenter.update(:form_buttons_div, r[
        :partial => "layouts/x_edit_buttons",
        :locals  => {
          :record_id    => @edit[:rec_id],
          :action_url   => action_url,
          :copy_button  => action_url == "copy_objects",
          :multi_record => @sb[:action] == "miq_ae_domain_priority_edit",
          :serialize    => @sb[:active_tab] == 'methods',
        }
      ])
    else
      # incase it was hidden for summary screen, and incase there were no records on show_list
      presenter.hide(:paging_div, :form_buttons_div)
    end

    presenter[:lock_sidebar] = @in_a_form && @edit

    if @record.kind_of?(MiqAeMethod) && !@in_a_form && !@angular_form
      presenter.set_visibility(!@record.inputs.blank?, :params_div)
    end

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    # Rebuild the toolbars
    presenter.reload_toolbars(:history => h_tb)
    if c_tb.present?
      presenter.show(:toolbar)
      presenter.reload_toolbars(:center => c_tb)
    else
      presenter.hide(:toolbar)
    end

    presenter[:record_id] = determine_record_id_for_presenter
    presenter[:osf_node] = x_node
    presenter.show_miq_buttons if @changed

    render :json => presenter.for_render
  end

  def build_type_options
    MiqAeField.available_aetypes.collect { |t| [t.titleize, t, {"data-icon" => ae_field_fonticon(t)}] }
  end

  def build_dtype_options
    MiqAeField.available_datatypes_for_ui.collect { |t| [t.titleize, t, {"data-icon" => ae_field_fonticon(t)}] }
  end

  def class_and_glyph(cls)
    case cls.to_s.split("::").last
    when "MiqAeClass"
      cls = "aec"
      glyphicon = "ff ff-class"
    when "MiqAeNamespace"
      cls = "aen"
      glyphicon = "pficon pficon-folder-open"
    when "MiqAeInstance"
      cls = "aei"
      glyphicon = "fa fa-file-text-o"
    when "MiqAeField"
      cls = "Field"
      glyphicon = "ff ff-field"
    when "MiqAeMethod"
      cls = "aem"
      glyphicon = "ff ff-method"
    end
    [cls, glyphicon]
  end

  def build_details_grid(view, mode = true)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    head = root.add_element("head")
    header = ""
    head.add_element("column", "type" => "ch", "width" => 25, "align" => "center") # Checkbox column
    new_column = head.add_element("column", "width" => "30", "align" => "left", "sort" => "na")
    new_column.add_attribute("type", 'ro')
    new_column.text = header
    new_column = head.add_element("column", "width" => "*", "align" => "left", "sort" => "na")
    new_column.add_attribute("type", 'ro')
    new_column.text = header

    # passing in mode, don't need to sort records for namaspace node, it will be passed in sorted order, need to show Namesaces first and then Classes
    records =
      if mode
        view.sort_by { |v| [v.display_name.to_s, v.name.to_s] }
      else
        view
      end
    records.each do |kids|
      cls, glyphicon = class_and_glyph(kids.class)
      rec_name = get_rec_name(kids)
      if rec_name
        rec_name = rec_name.gsub(/\n/, "\\n")
        rec_name = rec_name.gsub(/\t/, "\\t")
        rec_name = rec_name.tr('"', "'")
        rec_name = ERB::Util.html_escape(rec_name)
        rec_name = rec_name.gsub(/\\/, "&#92;")
      end
      srow = root.add_element("row", "id" => "#{cls}-#{to_cid(kids.id)}", "style" => "border-bottom: 1px solid #CCCCCC;color:black; text-align: center")
      srow.add_element("cell").text = "0" # Checkbox column unchecked
      srow.add_element("cell", "image" => "blank.png", "title" => cls.to_s, "style" => "border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;").text = REXML::CData.new("<i class='#{glyphicon}' alt='#{cls}' title='#{cls}'></i>")
      srow.add_element("cell", "image" => "blank.png", "title" => rec_name.to_s, "style" => "border-bottom: 1px solid #CCCCCC;text-align: left;height:28px;").text = rec_name
    end
    xml.to_s
  end

  def edit_item
    item = find_checked_items
    @sb[:row_selected] = item[0]
    if @sb[:row_selected].split('-')[0] == "aec"
      edit_class
    else
      edit_ns
    end
  end

  def edit_class
    assert_privileges("miq_ae_class_edit")
    if params[:pressed] == "miq_ae_item_edit" # came from Namespace details screen
      id = @sb[:row_selected].split('-')
      @ae_class = find_record_with_rbac(MiqAeClass, from_cid(id[1]))
    else
      @ae_class = find_record_with_rbac(MiqAeClass, params[:id])
    end
    set_form_vars
    # have to get name and set node info, to load multiple tabs correctly
    # rec_name = get_rec_name(@ae_class)
    # get_node_info("aec-#{to_cid(@ae_class.id)}")
    @in_a_form = true
    @in_a_form_props = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_fields
    assert_privileges("miq_ae_field_edit")
    if params[:pressed] == "miq_ae_item_edit" # came from Namespace details screen
      id = @sb[:row_selected].split('-')
      @ae_class = find_record_with_rbac(MiqAeClass, from_cid(id[1]))
    else
      @ae_class = find_record_with_rbac(MiqAeClass, params[:id])
    end
    fields_set_form_vars
    @in_a_form = true
    @in_a_form_fields = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_domain
    assert_privileges("miq_ae_domain_edit")
    edit_domain_or_namespace
  end

  def edit_ns
    assert_privileges("miq_ae_namespace_edit")
    edit_domain_or_namespace
  end

  def edit_instance
    assert_privileges("miq_ae_instance_edit")
    obj = find_checked_items
    if !obj.blank?
      @sb[:row_selected] = obj[0]
      id = @sb[:row_selected].split('-')
    else
      id = x_node.split('-')
    end
    initial_setup_for_instances_form_vars(from_cid(id[1]))
    set_instances_form_vars
    @in_a_form = true
    session[:changed] = @changed = false
    replace_right_cell
  end

  def edit_method
    assert_privileges("miq_ae_method_edit")
    obj = find_checked_items
    if !obj.blank?
      @sb[:row_selected] = obj[0]
      id = @sb[:row_selected].split('-')
    else
      id = x_node.split('-')
    end
    @ae_method = find_record_with_rbac(MiqAeMethod, from_cid(id[1]))
    if @ae_method.location == "playbook"
      angular_form_specific_data
    else
      set_method_form_vars
      @in_a_form = true
    end
    session[:changed] = @changed = false
    build_ae_tree(:ae_methods, :automate_tree)
    replace_right_cell
  end

  # Set form variables for edit
  def set_instances_form_vars
    session[:inst_data] = {}
    @edit = {
      :ae_inst_id  => @ae_inst.id,
      :ae_class_id => @ae_class.id,
      :rec_id      => @ae_inst.id || nil,
      :key         => "aeinst_edit__#{@ae_inst.id || "new"}",
      :new         => {}
    }
    @edit[:new][:ae_inst] = {}
    instance_column_names.each do |fld|
      @edit[:new][:ae_inst][fld] = @ae_inst.send(fld)
    end

    @edit[:new][:ae_values] = @ae_values.collect do |ae_value|
      value_column_names.each_with_object({}) do |fld, hash|
        hash[fld] = ae_value.send(fld)
      end
    end

    @edit[:new][:ae_fields] = @ae_class.ae_fields.collect do |ae_field|
      field_column_names.each_with_object({}) do |fld, hash|
        hash[fld] = ae_field.send(fld)
      end
    end

    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = if @edit[:rec_id].nil?
                         _("Adding a new Automate Instance")
                       else
                         _("Editing Automate Instance \"%{name}\"") % {:name => @ae_inst.name}
                       end
    session[:edit] = @edit
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_instance_field_changed
    return unless load_edit("aeinst_edit__#{params[:id]}", "replace_cell__explorer")
    get_instances_form_vars
    javascript_miq_button_visibility(@edit[:current] != @edit[:new])
  end

  def update_instance
    assert_privileges("miq_ae_instance_edit")
    return unless load_edit("aeinst_edit__#{params[:id]}", "replace_cell__explorer")
    get_instances_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of Automate Instance \"%{name}\" was cancelled by the user") % {:name => @ae_inst.name})
      @in_a_form = false
      replace_right_cell
    when "save"
      if @edit[:new][:ae_inst]["name"].blank?
        add_flash(_("Name is required"), :error)
      end
      if @flash_array
        javascript_flash
        return
      end
      set_instances_record_vars(@ae_inst) # Set the instance record variables, but don't save
      # Update the @ae_inst.ae_values directly because of update bug in RAILS
      # When saving a parent, the childrens updates are not getting saved
      set_instances_value_vars(@ae_values, @ae_inst) # Set the instance record variables, but don't save
      begin
        MiqAeInstance.transaction do
          @ae_inst.ae_values.each { |v| v.value = nil if v.value == "" }
          @ae_inst.save!
        end
      rescue => bang
        add_flash(_("Error during 'save': %{error_message}") % {:error_message => bang.message}, :error)
        @in_a_form = true
        javascript_flash
      else
        AuditEvent.success(build_saved_audit(@ae_class, @edit))
        session[:edit] = nil # clean out the saved info
        @in_a_form = false
        add_flash(_("Automate Instance \"%{name}\" was saved") % {:name => @ae_inst.name})
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    when "reset"
      set_instances_form_vars
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      @button = "reset"
      replace_right_cell
    end
  end

  def create_instance
    assert_privileges("miq_ae_instance_new")
    case params[:button]
    when "cancel"
      session[:edit] = nil # clean out the saved info
      add_flash(_("Add of new Automate Instance was cancelled by the user"))
      @in_a_form = false
      replace_right_cell
    when "add"
      return unless load_edit("aeinst_edit__new", "replace_cell__explorer")
      get_instances_form_vars
      if @edit[:new][:ae_inst]["name"].blank?
        add_flash(_("Name is required"), :error)
      end
      if @flash_array
        javascript_flash
        return
      end
      add_aeinst = MiqAeInstance.new
      set_instances_record_vars(add_aeinst)  # Set the instance record variables, but don't save
      set_instances_value_vars(@ae_values)   # Set the instance value record variables, but don't save
      begin
        MiqAeInstance.transaction do
          add_aeinst.ae_values = @ae_values
          add_aeinst.ae_values.each { |v| v.value = nil if v.value == "" }
          add_aeinst.save!
        end
      rescue => bang
        @in_a_form = true
        render_flash(_("Error during 'add': %{message}") % {:message => bang.message}, :error)
      else
        AuditEvent.success(build_created_audit(add_aeinst, @edit))
        add_flash(_("Automate Instance \"%{name}\" was added") % {:name => add_aeinst.name})
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    end
  end

  # Set form variables for edit
  def set_form_vars
    @in_a_form_props = true
    session[:field_data] = {}
    @edit = {}
    session[:edit] = {}
    @edit[:ae_class_id] = @ae_class.id
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:new_field] = {}
    @edit[:rec_id] = @ae_class.id || nil
    @edit[:key] = "aeclass_edit__#{@ae_class.id || "new"}"

    @edit[:new][:name] = @ae_class.name
    @edit[:new][:display_name] = @ae_class.display_name
    @edit[:new][:description] = @ae_class.description
    @edit[:new][:namespace] = @ae_class.namespace
    @edit[:new][:inherits] = @ae_class.inherits
    @edit[:inherits_from] = MiqAeClass.all.collect { |c| [c.fqname, c.fqname] }
    @edit[:current] = @edit[:new].dup
    @right_cell_text = if @edit[:rec_id].nil?
                         _("Adding a new Class")
                       else
                         _("Editing Class \"%{name}\"") % {:name => @ae_class.name}
                       end
    session[:edit] = @edit
    @in_a_form = true
  end

  # Set form variables for edit
  def fields_set_form_vars
    @in_a_form_fields = true
    session[:field_data] = {}
    @edit = {
      :ae_class_id      => @ae_class.id,
      :rec_id           => @ae_class.id,
      :new_field        => {},
      :key              => "aefields_edit__#{@ae_class.id || "new"}",
      :fields_to_delete => []
    }

    @edit[:new] = {
      :datatypes => build_dtype_options,    # setting dtype combo for adding a new field
      :aetypes   => build_type_options      # setting aetype combo for adding a new field
    }

    @edit[:new][:fields] = @ae_class.ae_fields.sort_by { |a| [a.priority.to_i] }.collect do |fld|
      field_attributes.each_with_object({}) do |column, hash|
        hash[column] = fld.send(column)
      end
    end

    # combo to show existing fields
    @combo_xml = build_type_options
    # passing in fields because that's how many combo boxes we need
    @dtype_combo_xml = build_dtype_options
    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = if @edit[:rec_id].nil?
                         _("Adding a new Class Schema")
                       else
                         _("Editing Class Schema \"%{name}\"") % {:name => @ae_class.name}
                       end
    session[:edit] = @edit
  end

  # Set form variables for edit
  def set_method_form_vars
    session[:field_data] = {}
    @ae_class = ae_class_for_instance_or_method(@ae_method)
    @edit = {}
    session[:edit] = {}
    @edit[:ae_method_id] = @ae_method.id
    @edit[:fields_to_delete] = []
    @edit[:new] = {}
    @edit[:new_field] = {}
    @edit[:ae_class_id] = @ae_class.id
    @edit[:rec_id] = @ae_method.id || nil
    @edit[:key] = "aemethod_edit__#{@ae_method.id || "new"}"
    @sb[:form_vars_set] = true
    @sb[:squash_state] ||= true

    @edit[:new][:name] = @ae_method.name
    @edit[:new][:display_name] = @ae_method.display_name
    @edit[:new][:scope] = "instance"
    @edit[:new][:language] = "ruby"
    @edit[:new][:available_locations] = MiqAeMethod.available_locations unless @ae_method.id
    @edit[:new][:available_expression_objects] = MiqAeMethod.available_expression_objects.sort
    @edit[:new][:location] = @ae_method.location
    if @edit[:new][:location] == "expression"
      expr_hash = YAML.load(@ae_method.data)
      if expr_hash[:db] && expr_hash[:expression]
        @edit[:new][:expression] = expr_hash[:expression]
        expression_setup(expr_hash[:db])
      end
    else
      @edit[:new][:data] = @ae_method.data.to_s
    end
    @edit[:new][:data] = @ae_method.data.to_s
    @edit[:default_verify_status] = @edit[:new][:location] == "inline" && @edit[:new][:data] && @edit[:new][:data] != ""
    @edit[:new][:fields] = @ae_method.inputs.collect do |input|
      method_input_column_names.each_with_object({}) do |column, hash|
        hash[column] = input.send(column)
      end
    end
    @edit[:new][:available_datatypes] = MiqAeField.available_datatypes_for_ui
    @edit[:new][:embedded_methods] = @ae_method.embedded_methods if @ae_method.location == 'inline'
    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = if @edit[:rec_id].nil?
                         _("Adding a new Automate Method")
                       else
                         _("Editing Automate Method \"%{name}\"") % {:name => @ae_method.name}
                       end
    session[:log_depot_default_verify_status] = false
    session[:edit] = @edit
    session[:changed] = @changed = false
  end

  def expression_setup(db)
    @edit[:expression_method] = true
    @edit[:new][:exp_object] = db
    if params[:exp_object] || params[:cls_exp_object]
      session[:adv_search] = nil
      @edit[@expkey] = @edit[:new][@expkey] = nil
    end
    adv_search_build(db)
  end

  def expression_cleanup
    @edit[:expression_method] = false
  end

  def ae_class_for_instance_or_method(record)
    record.id ? record.ae_class : MiqAeClass.find(from_cid(x_node.split("-").last))
  end

  def validate_method_data
    return unless load_edit("aemethod_edit__#{params[:id]}", "replace_cell__explorer")
    @edit[:new][:data] = params[:cls_method_data] if params[:cls_method_data]
    @edit[:new][:data] = params[:method_data] if params[:method_data]
    res = MiqAeMethod.validate_syntax(@edit[:new][:data])
    line = 0
    if !res
      add_flash(_("Data validated successfully"))
    else
      res.each do |err|
        line = err[0] if line.zero?
        add_flash(_("Error on line %{line_num}: %{err_txt}") % {:line_num => err[0], :err_txt => err[1]}, :error)
      end
    end
    render :update do |page|
      page << javascript_prologue
      page << "if (miqDomElementExists('cls_method_data')){"
      page << "var ta = document.getElementById('cls_method_data');"
      page << "} else {"
      page << "var ta = document.getElementById('method_data');"
      page << "}"
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "var lineHeight = ta.clientHeight / ta.rows;"
      page << "ta.scrollTop = (#{line.to_i}-1) * lineHeight;"
      if line > 0
        if @sb[:row_selected]
          page << "$('#cls_method_data_lines').scrollTop(ta.scrollTop);"
          page << "$('#cls_method_data').scrollTop(ta.scrollTop);"
        else
          page << "$('#method_data_lines').scrollTop(ta.scrollTop);"
          page << "$('#method_data').scrollTop(ta.scrollTop);"
        end
      end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("aeclass_edit__#{params[:id]}", "replace_cell__explorer")
    get_form_vars
    javascript_miq_button_visibility(@edit[:new] != @edit[:current])
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def fields_form_field_changed
    return unless load_edit("aefields_edit__#{params[:id]}", "replace_cell__explorer")
    fields_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      unless %w(up down).include?(params[:button])
        if params[:field_datatype] == "password"
          page << javascript_hide("field_default_value")
          page << javascript_show("field_password_value")
          page << "$('#field_password_value').val('');"
          session[:field_data][:default_value] =
            @edit[:new_field][:default_value] = ''
        elsif params[:field_datatype]
          page << javascript_hide("field_password_value")
          page << javascript_show("field_default_value")
          page << "$('#field_default_value').val('');"
          session[:field_data][:default_value] =
            @edit[:new_field][:default_value] = ''
        end
        params.keys.each do |field|
          next unless field.to_s.starts_with?("fields_datatype")

          f = field.split('fields_datatype')
          def_field = "fields_default_value_" << f[1].to_s
          pwd_field = "fields_password_value_" << f[1].to_s
          if @edit[:new][:fields][f[1].to_i]['datatype'] == "password"
            page << javascript_hide(def_field)
            page << javascript_show(pwd_field)
            page << "$('##{pwd_field}').val('');"
          else
            page << javascript_hide(pwd_field)
            page << javascript_show(def_field)
            page << "$('##{def_field}').val('');"
          end
          @edit[:new][:fields][f[1].to_i]['default_value'] = nil
        end
      end
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_method_field_changed
    if !@sb[:form_vars_set] # workaround to prevent an error that happens when IE sends a transaction form form even after save button is clicked when there is text_area in the form
      head :ok
    else
      return unless load_edit("aemethod_edit__#{params[:id]}", "replace_cell__explorer")
      get_method_form_vars

      if @edit[:new][:location] == 'expression'
        @edit[:new][:exp_object] ||= @edit[:new][:available_expression_objects].first
        exp_object = params[:cls_exp_object] || params[:exp_object] || @edit[:new][:exp_object]
        expression_setup(exp_object) if exp_object
      else
        expression_cleanup
      end
      if row_selected_in_grid?
        @refresh_div = "class_methods_div"
        @refresh_partial = "class_methods"
        @field_name = "cls_method"
      else
        @refresh_div = "method_inputs_div"
        @refresh_partial = "method_inputs"
        @field_name = "method"
      end
      if @edit[:current][:location] == "inline" && @edit[:current][:data]
        @edit[:method_prev_data] = @edit[:current][:data]
      end
      @edit[:new][:data] = if @edit[:new][:location] == "inline" && !params[:cls_method_data] &&
                              !params[:method_data] && !params[:transOne]
                             if !@edit[:method_prev_data]
                               MiqAeMethod.default_method_text
                             else
                               @edit[:method_prev_data]
                             end
                           elsif params[:cls_method_location] || params[:method_location]
                             # reset data if location is changed
                             ''
                           end
      build_ae_tree(:ae_methods, :automate_tree)
      @changed = (@edit[:new] != @edit[:current])
      @edit[:default_verify_status] = @edit[:new][:location] == "inline" && @edit[:new][:data] && @edit[:new][:data] != ""
      angular_form_specific_data if @edit[:new][:location] == "playbook"
      render :update do |page|
        page << javascript_prologue
        page.replace_html('form_div', :partial => 'method_form', :locals => {:prefix => ""}) if @edit[:new][:location] == 'expression'
        if @edit[:new][:location] == "playbook"
          page.replace_html(@refresh_div, :partial => 'angular_method_form')
          page << javascript_hide("form_buttons_div")
        elsif @refresh_div && (params[:cls_method_location] || params[:exp_object] || params[:cls_exp_object])
          page.replace_html(@refresh_div, :partial => @refresh_partial)
        end

        if params[:cls_field_datatype]
          if session[:field_data][:datatype] == "password"
            page << javascript_hide("cls_field_default_value")
            page << javascript_show("cls_field_password_value")
            page << "$('#cls_field_password_value').val('');"
          else
            page << javascript_hide("cls_field_password_value")
            page << javascript_show("cls_field_default_value")
            page << "$('#cls_field_default_value').val('');"
          end
        end
        if params[:method_field_datatype]
          if session[:field_data][:datatype] == "password"
            page << javascript_hide("method_field_default_value")
            page << javascript_show("method_field_password_value")
            page << "$('#method_field_password_value').val('');"
          else
            page << javascript_hide("method_field_password_value")
            page << javascript_show("method_field_default_value")
            page << "$('#method_field_default_value').val('');"
          end
        end

        params.keys.each do |field|
          if field.to_s.starts_with?("cls_fields_datatype_")
            f = field.split('cls_fields_datatype_')
            def_field = "cls_fields_value_" << f[1].to_s
            pwd_field = "cls_fields_password_value_" << f[1].to_s
          elsif field.to_s.starts_with?("fields_datatype_")
            f = field.split('fields_datatype_')
            def_field = "fields_value_" << f[1].to_s
            pwd_field = "fields_password_value_" << f[1].to_s
          end

          next unless f

          if @edit[:new][:fields][f[1].to_i]['datatype'] == "password"
            page << javascript_hide(def_field)
            page << javascript_show(pwd_field)
            page << "$('##{pwd_field}').val('');"
          else
            page << javascript_hide(pwd_field)
            page << javascript_show(def_field)
            page << "$('##{def_field}').val('');"
          end
          @edit[:new][:fields][f[1].to_i]['default_value'] = nil
        end
        if @edit[:default_verify_status] != session[:log_depot_default_verify_status]
          session[:log_depot_default_verify_status] = @edit[:default_verify_status]
          page << if @edit[:default_verify_status]
                    "miqValidateButtons('show', 'default_');"
                  else
                    "miqValidateButtons('hide', 'default_');"
                  end
        end
        page << javascript_for_miq_button_visibility_changed(@changed)
        page << "miqSparkle(false)"
      end
    end
  end

  def method_form_fields
    method = params[:id] == "new" ? MiqAeMethod.new : MiqAeMethod.find(params[:id])
    method_hash = {
      :name                => method.name,
      :display_name        => method.display_name,
      :namespace_path      => @sb[:namespace_path],
      :class_id            => method.id ? method.class_id : MiqAeClass.find(from_cid(x_node.split("-").last)).id,
      :location            => 'playbook',
      :language            => 'ruby',
      :scope               => "instance",
      :available_datatypes => MiqAeField.available_datatypes_for_ui,
      :config_info         => {
        :repository_id         => method.options[:repository_id] || '',
        :playbook_id           => method.options[:playbook_id] || '',
        :credential_id         => method.options[:credential_id] || '',
        :network_credential_id => method.options[:network_credential_id] || '',
        :cloud_credential_id   => method.options[:cloud_credential_id] || '',
        :verbosity             => method.options[:verbosity],
        :become_enabled        => method.options[:become_enabled] || false,
        :extra_vars            => method.inputs
      }
    }
    render :json => method_hash
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_ns_field_changed
    return unless load_edit("aens_edit__#{params[:id]}", "replace_cell__explorer")
    get_ns_form_vars
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  def update
    assert_privileges("miq_ae_class_edit")
    return unless load_edit("aeclass_edit__#{params[:id]}", "replace_cell__explorer")
    get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of Automate Class \"%{name}\" was cancelled by the user") % {:name => @ae_class.name})
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_class = find_record_with_rbac(MiqAeClass, params[:id])
      set_record_vars(ae_class) # Set the record variables, but don't save
      begin
        MiqAeClass.transaction do
          ae_class.save!
        end
      rescue => bang
        add_flash(_("Error during 'save': %{error_message}") % {:error_message => bang.message}, :error)
        session[:changed] = @changed
        @changed = true
        javascript_flash
      else
        add_flash(_("Automate Class \"%{name}\" was saved") % {:name => ae_class.fqname})
        AuditEvent.success(build_saved_audit(ae_class, @edit))
        session[:edit] = nil # clean out the saved info
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    when "reset"
      set_form_vars
      session[:changed] = @changed = false
      add_flash(_("All changes have been reset"), :warning)
      @button = "reset"
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell(:replace_trees => [:ae])
    end
  end

  def update_fields
    return unless load_edit("aefields_edit__#{params[:id]}", "replace_cell__explorer")
    fields_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(_("Edit of schema for Automate Class \"%{name}\" was cancelled by the user") % {:name => @ae_class.name})
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_class = find_record_with_rbac(MiqAeClass, params[:id])
      begin
        MiqAeClass.transaction do
          set_field_vars(ae_class)
          ae_class.ae_fields.destroy(MiqAeField.where(:id => @edit[:fields_to_delete]))
          ae_class.ae_fields.each { |fld| fld.default_value = nil if fld.default_value == "" }
          ae_class.save!
        end  # end of transaction
      rescue => bang
        add_flash(_("Error during 'save': %{error_message}") % {:error_message => bang.message}, :error)
        session[:changed] = @changed = true
        javascript_flash
      else
        add_flash(_("Schema for Automate Class \"%{name}\" was saved") % {:name => ae_class.name})
        AuditEvent.success(build_saved_audit(ae_class, @edit))
        session[:edit] = nil  # clean out the saved info
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    when "reset"
      fields_set_form_vars
      session[:changed] = @changed = false
      add_flash(_("All changes have been reset"), :warning)
      @button = "reset"
      @in_a_form = true
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell(:replace_trees => [:ae])
    end
  end

  def update_ns
    assert_privileges("miq_ae_namespace_edit")
    return unless load_edit("aens_edit__#{params[:id]}", "replace_cell__explorer")
    get_ns_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => @edit[:typ]), :name => @ae_ns.name})
      @in_a_form = false
      replace_right_cell
    when "save"
      ae_ns = find_record_with_rbac(@edit[:typ].constantize, params[:id])
      ns_set_record_vars(ae_ns) # Set the record variables, but don't save
      begin
        ae_ns.save!
      rescue => bang
        add_flash(_("Error during 'save': %{message}") % {:message => bang.message}, :error)
        session[:changed] = @changed
        @changed = true
        javascript_flash
      else
        add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => @edit[:typ]), :name => get_record_display_name(ae_ns)})
        AuditEvent.success(build_saved_audit(ae_ns, @edit))
        session[:edit] = nil # clean out the saved info
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
      end
    when "reset"
      ns_set_form_vars
      session[:changed] = @changed = false
      add_flash(_("All changes have been reset"), :warning)
      @button = "reset"
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell(:replace_trees => [:ae])
    end
  end

  def add_update_method
    assert_privileges("miq_ae_method_edit")
    case params[:button]
    when "cancel"
      if params[:id] && params[:id] != "new"
        method = find_record_with_rbac(MiqAeMethod, params[:id])
        add_flash(_("Edit of Automate Method \"%{name}\" was cancelled by the user") % {:name => method.name})
      else
        add_flash(_("Add of Automate Method was cancelled by the user"))
      end
      replace_right_cell
    when "add", "save"
      method = params[:id] != "new" ? find_record_with_rbac(MiqAeMethod, params[:id]) : MiqAeMethod.new
      method.name = params["name"]
      method.display_name = params["display_name"]
      method.location = params["location"]
      method.language = params["language"]
      method.scope = params["scope"]
      method.class_id = params[:class_id]
      method.options = set_playbook_data
      begin
        MiqAeMethod.transaction do
          to_save, to_delete = playbook_inputs(method)
          method.inputs.destroy(MiqAeField.where(:id => to_delete))
          method.inputs = to_save
          method.save!
        end
      rescue => bang
        add_flash(_("Error during 'save': %{error_message}") % {:error_message => bang.message}, :error)
        javascript_flash
      else
        old_method_attributes = method.attributes.clone
        add_flash(_("Automate Method \"%{name}\" was saved") % {:name => method.name})
        AuditEvent.success(build_saved_audit_hash_angular(old_method_attributes, method, params[:button] == "add"))
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    end
  end

  def update_method
    assert_privileges("miq_ae_method_edit")
    return unless load_edit("aemethod_edit__#{params[:id]}", "replace_cell__explorer")
    get_method_form_vars
    @changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of Automate Method \"%{name}\" was cancelled by the user") % {:name => @ae_method.name})
      @sb[:form_vars_set] = false
      @in_a_form = false
      replace_right_cell
    when "save"
      # dont allow save if expression has not been added or existing one has been removed
      validate_expression("save") if @edit[:new][:location] == 'expression'
      return if flash_errors?

      ae_method = find_record_with_rbac(MiqAeMethod, params[:id])
      set_method_record_vars(ae_method) # Set the record variables, but don't save
      begin
        MiqAeMethod.transaction do
          set_input_vars(ae_method)
          ae_method.inputs.destroy(MiqAeField.where(:id => @edit[:fields_to_delete]))
          ae_method.inputs.each { |fld| fld.default_value = nil if fld.default_value == "" }
          ae_method.embedded_methods = @edit[:new][:embedded_methods] if @edit[:new][:location] == 'inline'
          ae_method.save!
        end
      rescue => bang
        add_flash(_("Error during 'save': %{error_message}") % {:error_message => bang.message}, :error)
        session[:changed] = @changed
        @changed = true
        javascript_flash
      else
        add_flash(_("Automate Method \"%{name}\" was saved") % {:name => ae_method.name})
        AuditEvent.success(build_saved_audit(ae_method, @edit))
        session[:edit] = nil # clean out the saved info
        @sb[:form_vars_set] = false
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
        return
      end
    when "reset"
      set_method_form_vars
      session[:changed] = @changed = false
      @in_a_form = true
      add_flash(_("All changes have been reset"), :warning)
      @button = "reset"
      build_ae_tree(:ae_methods, :automate_tree)
      replace_right_cell
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell
    end
  end

  def new
    assert_privileges("miq_ae_class_new")
    @ae_class = MiqAeClass.new
    set_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def new_instance
    assert_privileges("miq_ae_instance_new")
    initial_setup_for_instances_form_vars(nil)
    set_instances_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def new_method
    assert_privileges("miq_ae_method_new")
    @ae_method = MiqAeMethod.new
    set_method_form_vars
    @in_a_form = true
    replace_right_cell
  end

  def create
    assert_privileges("miq_ae_class_new")
    return unless load_edit("aeclass_edit__new", "replace_cell__explorer")
    get_form_vars
    @in_a_form = true
    case params[:button]
    when "cancel"
      add_flash(_("Add of new Automate Class was cancelled by the user"))
      @in_a_form = false
      replace_right_cell(:replace_trees => [:ae])
    when "add"
      add_aeclass = MiqAeClass.new
      set_record_vars(add_aeclass) # Set the record variables, but don't save
      begin
        MiqAeClass.transaction do
          add_aeclass.save!
        end
      rescue => bang
        add_flash(_("Error during 'add': %{error_message}") % {:error_message => bang.message}, :error)
        @in_a_form = true
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg", :partial => "layouts/flash_msg")
        end
      else
        add_flash(_("Automate Class \"%{name}\" was added") % {:name => add_aeclass.fqname})
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell(:replace_trees => [:ae])
    end
  end

  def data_for_expression
    {:db         => @edit[:new][:exp_object],
     :expression => @edit[:new][:expression]}.to_yaml
  end

  def create_method
    assert_privileges("miq_ae_method_new")
    @in_a_form = true
    case params[:button]
    when "cancel"
      add_flash(_("Add of new Automate Method was cancelled by the user"))
      @sb[:form_vars_set] = false
      @in_a_form = false
      replace_right_cell
    when "add"
      return unless load_edit("aemethod_edit__new", "replace_cell__explorer")
      get_method_form_vars

      # dont allow add if expression has not been added or existing one has been removed
      validate_expression("add") if @edit[:new][:location] == 'expression'
      return if flash_errors?

      add_aemethod = MiqAeMethod.new
      set_method_record_vars(add_aemethod) # Set the record variables, but don't save
      begin
        MiqAeMethod.transaction do
          add_aemethod.save!
          set_field_vars(add_aemethod)
          add_aemethod.save!
        end
      rescue => bang
        add_flash(_("Error during 'add': %{error_message}") % {:error_message => bang.message}, :error)
        @in_a_form = true
        javascript_flash
      else
        add_flash(_("Automate Method \"%{name}\" was added") % {:name => add_aemethod.name})
        @sb[:form_vars_set] = false
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      @sb[:form_vars_set] = false
      replace_right_cell(:replace_trees => [:ae])
    end
  end

  def create_ns
    assert_privileges("miq_ae_namespace_new")
    return unless load_edit("aens_edit__new", "replace_cell__explorer")
    get_ns_form_vars
    case params[:button]
    when "cancel"
      add_flash(_("Add of new %{record} was cancelled by the user") % {:record => ui_lookup(:model => @edit[:typ])})
      @in_a_form = false
      replace_right_cell
    when "add"
      add_ae_ns = if @edit[:typ] == "MiqAeDomain"
                    current_tenant.ae_domains.new
                  else
                    MiqAeNamespace.new(:parent_id => from_cid(x_node.split('-')[1]))
                  end
      ns_set_record_vars(add_ae_ns) # Set the record variables, but don't save
      if add_ae_ns.valid? && !flash_errors? && add_ae_ns.save
        add_flash(_("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => add_ae_ns.class.name), :name => get_record_display_name(add_ae_ns)})
        @in_a_form = false
        replace_right_cell(:replace_trees => [:ae])
      else
        add_ae_ns.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        javascript_flash
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell
    end
  end

  # AJAX driven routine to select a classification entry
  def field_select
    fields_get_form_vars
    @combo_xml = build_type_options
    @dtype_combo_xml = build_dtype_options
    session[:field_data] = {}
    @edit[:new_field][:substitute] = session[:field_data][:substitute] = true
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace("class_fields_div", :partial => "class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a classification entry
  def field_accept
    fields_get_form_vars
    @changed = (@edit[:new] != @edit[:current])
    @combo_xml = build_type_options
    @dtype_combo_xml = build_dtype_options
    render :update do |page|
      page << javascript_prologue
      page.replace("class_fields_div", :partial => "class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to delete a classification entry
  def field_delete
    fields_get_form_vars
    @combo_xml       = build_type_options
    @dtype_combo_xml = build_dtype_options

    if params.key?(:id) && @edit[:fields_to_delete].exclude?(params[:id])
      @edit[:fields_to_delete].push(params[:id])
    end

    @edit[:new][:fields].delete_at(params[:arr_id].to_i)
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace("class_fields_div", :partial => "class_fields")
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a classification entry
  def field_method_select
    get_method_form_vars
    @refresh_div = "inputs_div"
    @refresh_partial = "inputs"
    @changed = (@edit[:new] != @edit[:current])
    @in_a_form = true
    render :update do |page|
      page << javascript_prologue
      page.replace_html(@refresh_div, :partial => @refresh_partial)
      if row_selected_in_grid?
        page << javascript_show("class_methods_div")
        page << javascript_focus('cls_field_name')
      else
        page << javascript_show("method_inputs_div")
        page << javascript_focus('field_name')
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << javascript_show("inputs_div")
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a classification entry
  def field_method_accept
    get_method_form_vars
    @refresh_div = "inputs_div"
    @refresh_partial = "inputs"
    session[:field_data] = {}
    @changed = (@edit[:new] != @edit[:current])
    @in_a_form = true
    render :update do |page|
      page << javascript_prologue
      page.replace_html(@refresh_div, :partial => @refresh_partial)
      if row_selected_in_grid?
        page << javascript_show("class_methods_div")
      else
        page << javascript_show("method_inputs_div")
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << javascript_show("inputs_div")
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to delete a classification entry
  def field_method_delete
    get_method_form_vars
    @refresh_div = "inputs_div"
    @refresh_partial = "inputs"

    if params.key?(:id) && @edit[:fields_to_delete].exclude?(params[:id])
      @edit[:fields_to_delete].push(params[:id])
    end

    @edit[:new][:fields].delete_at(params[:arr_id].to_i)

    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace_html(@refresh_div, :partial => @refresh_partial)
      if row_selected_in_grid?
        page << javascript_show("class_methods_div")
      else
        page << javascript_show("method_inputs_div")
      end
      page << javascript_for_miq_button_visibility(@changed)
      page << javascript_show("inputs_div")
      page << "miqSparkle(false);"
    end
  end

  def handle_up_down_buttons(hash_key, field_name)
    case params[:button]
    when 'up'
      move_selected_fields_up(@edit[:new][hash_key], params[:seq_fields], field_name)
    when 'down'
      move_selected_fields_down(@edit[:new][hash_key], params[:seq_fields], field_name)
    end
  end

  # Get variables from user edit form
  def fields_seq_field_changed
    return unless load_edit("fields_edit__seq", "replace_cell__explorer")

    unless handle_up_down_buttons(:fields_list, _('Fields'))
      render_flash
      return
    end

    render :update do |page|
      page << javascript_prologue
      page.replace('column_lists', :partial => 'fields_seq_form')
      @changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(@changed) if @changed
      page << "miqsparkle(false);"
    end
  end

  def fields_seq_edit
    assert_privileges("miq_ae_field_seq")
    case params[:button]
    when "cancel"
      @sb[:action] = session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of Class Schema Sequence was cancelled by the user"))
      @in_a_form = false
      replace_right_cell

    when "save"
      return unless load_edit("fields_edit__seq", "replace_cell__explorer")
      ae_class = MiqAeClass.find(@edit[:ae_class_id])
      indexed_ae_fields = ae_class.ae_fields.index_by(&:name)
      @edit[:new][:fields_list].each_with_index do |f, i|
        fname = f.split('(').last.split(')').first # leave display name and parenthesis out
        indexed_ae_fields[fname].try(:priority=, i + 1)
      end

      unless ae_class.save
        flash_validation_errors(ae_class)
        @in_a_form = true
        @changed = true
        javascript_flash
        return
      end

      AuditEvent.success(build_saved_audit(ae_class, @edit))
      add_flash(_("Class Schema Sequence was saved"))
      @sb[:action] = @edit = session[:edit] = nil # clean out the saved info
      @in_a_form = false
      replace_right_cell

    when "reset", nil # Reset or first time in
      id = params[:id] ? params[:id] : from_cid(@edit[:ae_class_id])
      @in_a_form = true
      fields_seq_edit_screen(id)
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell
    end
  end

  def priority_form_field_changed
    return unless load_edit(params[:id], "replace_cell__explorer")
    @in_a_form = true

    unless handle_up_down_buttons(:domain_order, _('Domains'))
      render_flash
      return
    end

    render :update do |page|
      page << javascript_prologue
      page.replace('domains_list',
                   :partial => 'domains_priority_form',
                   :locals  => {:action => "domains_priority_edit"})
      @changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(@changed) if @changed
      page << "miqsparkle(false);"
    end
  end

  def domains_priority_edit
    assert_privileges("miq_ae_domain_priority_edit")
    case params[:button]
    when "cancel"
      @sb[:action] = @in_a_form = @edit = session[:edit] = nil  # clean out the saved info
      add_flash(_("Edit of Priority Order was cancelled by the user"))
      replace_right_cell
    when "save"
      return unless load_edit("priority__edit", "replace_cell__explorer")
      domains = @edit[:new][:domain_order].reverse!.collect do |domain|
        MiqAeDomain.find_by(:name => domain.split(' (Locked)').first).id
      end
      current_tenant.reset_domain_priority_by_ordered_ids(domains)
      add_flash(_("Priority Order was saved"))
      @sb[:action] = @in_a_form = @edit = session[:edit] = nil  # clean out the saved info
      replace_right_cell(:replace_trees => [:ae])
    when "reset", nil # Reset or first time in
      priority_edit_screen
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      session[:changed] = @changed = false
      replace_right_cell
    end
  end

  def objects_to_copy
    ids = find_checked_items
    if ids
      items_without_prefix = []
      ids.each do |item|
        values = item.split("-")
        # remove any namespaces that were selected in grid
        items_without_prefix.push(values.last) unless values.first == "aen"
      end
      items_without_prefix
    else
      [params[:id]]
    end
  end

  def copy_objects
    ids = objects_to_copy
    if ids.blank?
      add_flash(_("Copy does not apply to selected Automate Namespace"), :error)
      @sb[:action] = session[:edit] = nil
      @in_a_form = false
      replace_right_cell
      return
    end
    case params[:button]
    when "cancel"
      copy_cancel
    when "copy"
      copy_save
    when "reset", nil # Reset or first time in
      action = params[:pressed] || @sb[:action]
      klass = case action
              when "miq_ae_class_copy"
                MiqAeClass
              when "miq_ae_instance_copy"
                MiqAeInstance
              when "miq_ae_method_copy"
                MiqAeMethod
              end
      copy_reset(klass, ids, action)
    end
  end

  def form_copy_objects_field_changed
    return unless load_edit("copy_objects__#{params[:id]}", "replace_cell__explorer")
    copy_objects_get_form_vars
    build_ae_tree(:automate, :automate_tree)
    @changed = (@edit[:new] != @edit[:current])
    @changed = @edit[:new][:override_source] if @edit[:new][:namespace].nil?
    render :update do |page|
      page << javascript_prologue
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace("form_div", :partial => "copy_objects_form") if params[:domain] || params[:override_source]
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  def ae_tree_select_toggle
    @edit = session[:edit]
    self.x_active_tree = :ae_tree
    method_edit_or_new_method? ? at_tree_select_toggle(:method) : at_tree_select_toggle(:namespace)

    if params[:button] == 'submit'
      x_node_set(@edit[:active_id], :automate_tree)
      @edit[:namespace] = @edit[:new][:namespace] unless method_edit_or_new_method?
    end

    session[:edit] = @edit
  end

  def embedded_methods_remove
    @edit[:new][:embedded_methods].delete_at(params[:id].to_i)
    build_ae_tree(:ae_methods, :automate_tree)
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page << javascript_for_miq_button_visibility(@changed)
      page.replace("embedded_methods_div", :partial => "embedded_methods")
      page << "miqSparkle(false);"
    end
  end

  def ae_tree_select
    @edit = session[:edit]
    method_edit_or_new_method? ? at_tree_select(:method) : at_tree_select(:namespace)
    session[:edit] = @edit
  end

  def x_show
    typ, id = params[:id].split("-")
    @record = TreeBuilder.get_model_for_prefix(typ).constantize.find(from_cid(id))
    tree_select
  end

  def refresh_git_domain
    if params[:button] == "save"
      git_based_domain_import_service.import(params[:git_repo_id], params[:git_branch_or_tag], current_tenant.id)

      add_flash(_("Successfully refreshed!"), :info)
    else
      add_flash(_("Git based refresh canceled"), :info)
    end

    session[:edit] = nil
    @in_a_form = false
    replace_right_cell(:replace_trees => [:ae])
  end

  private

  def method_edit_or_new_method?
    %w(miq_ae_method_edit miq_ae_method_new).include?(@sb[:action])
  end

  def playbook_inputs(method)
    existing_inputs = method.inputs
    new_inputs = params[:extra_vars] ? params[:extra_vars] : []
    inputs_to_save = []
    inputs_to_delete = []
    new_inputs.each do |i, input|
      field = input.length == 4 ? MiqAeField.find_by(:id => input.last) : MiqAeField.new
      field.name = input[0]
      field.default_value = input[1] == "" ? nil : input[1]
      field.datatype = input[2]
      field.priority = i
      inputs_to_save.push(field)
    end
    existing_inputs.each do |existing_input|
      inputs_to_delete.push(existing_input.id) unless inputs_to_save.any? { |i| i.id == existing_input.id }
    end
    return inputs_to_save, inputs_to_delete
  end

  def set_playbook_data
    params_list = %i(repository_id
                     playbook_id
                     credential_id
                     verbosity
                     network_credential_id
                     cloud_credential_id)
    boolean_params_list = %i(become_enabled)
    params_hash = copy_params_if_set({}, params, params_list)
    copy_boolean_params(params_hash, params, boolean_params_list)
  end

  def angular_form_specific_data
    @record = @ae_method
    @ae_class = ae_class_for_instance_or_method(@ae_method)
    @current_region = MiqRegion.my_region.region
    @angular_form = true
  end

  def validate_expression(task)
    if @edit[@expkey][:expression]["???"] == "???"
      add_flash(_("Error during '%{task}': Expression element is required") % {:task => _(task)}, :error)
      @in_a_form = true
      javascript_flash
    end
  end

  def features
    [ApplicationController::Feature.new_with_hash(:role        => "miq_ae_class_explorer",
                                                  :role_any    => true,
                                                  :name        => :ae,
                                                  :accord_name => "datastores",
                                                  :title       => _("Datastore"))]
  end

  def initial_setup_for_instances_form_vars(ae_inst_id)
    @ae_inst = ae_inst_id ? MiqAeInstance.find(ae_inst_id) : MiqAeInstance.new
    @ae_class = ae_class_for_instance_or_method(@ae_inst)

    @ae_values = @ae_class.ae_fields.sort_by { |a| [a.priority.to_i] }.collect do |fld|
      MiqAeValue.find_or_initialize_by(:field_id => fld.id.to_s, :instance_id => @ae_inst.id.to_s)
    end
  end

  def instance_column_names
    %w(name description display_name)
  end

  def field_column_names
    %w(aetype collect datatype default_value display_name name on_entry on_error on_exit substitute)
  end

  def value_column_names
    %w(collect display_name on_entry on_error on_exit max_retries max_time value)
  end

  def method_input_column_names
    %w(datatype default_value id name priority)
  end

  def copy_objects_get_form_vars
    %w(domain override_existing override_source namespace new_name).each do |field|
      fld = field.to_sym
      if %w(override_existing override_source).include?(field)
        @edit[:new][fld] = params[fld] == "1" if params[fld]
        @edit[:new][:namespace] = nil if @edit[:new][:override_source]
      else
        @edit[:new][fld] = params[fld] if params[fld]
        if fld == :domain && params[fld]
          # save domain in sandbox, treebuilder doesnt have access to @edit
          @sb[:domain_id]         = params[fld]
          @edit[:new][:namespace] = nil
          @edit[:new][:new_name]  = nil
        end
      end
    end
  end

  def copy_save
    assert_privileges(@sb[:action])
    return unless load_edit("copy_objects__#{params[:id]}", "replace_cell__explorer")

    begin
      @record = @edit[:typ].find(@edit[:rec_id])
      domain = MiqAeDomain.find(@edit[:new][:domain])
      @edit[:new][:new_name] = nil if @edit[:new][:new_name] == @edit[:old_name]
      options = {
        :ids                => @edit[:selected_items].keys,
        :domain             => domain.name,
        :namespace          => @edit[:new][:namespace],
        :overwrite_location => @edit[:new][:override_existing],
        :new_name           => @edit[:new][:new_name],
        :fqname             => @edit[:fqname]
      }
      res = @edit[:typ].copy(options)
    rescue => bang
      render_flash(_("Error during '%{record} copy': %{error_message}") %
        {:record => ui_lookup(:model => @edit[:typ].to_s), :error_message => bang.message}, :error)
      return
    end

    model = @edit[:selected_items].count > 1 ? :models : :model
    add_flash(_("Copy selected %{record} was saved") % {:record => ui_lookup(model => @edit[:typ].to_s)})
    @record = res.kind_of?(Array) ? @edit[:typ].find(res.first) : res
    self.x_node = "#{TreeBuilder.get_prefix_for_model(@edit[:typ])}-#{to_cid(@record.id)}"
    @in_a_form = @changed = session[:changed] = false
    @sb[:action] = @edit = session[:edit] = nil
    replace_right_cell
  end

  def copy_reset(typ, ids, button_pressed)
    assert_privileges(button_pressed)
    @changed = session[:changed] = @in_a_form = true
    copy_objects_edit_screen(typ, ids, button_pressed)
    if params[:button] == "reset"
      add_flash(_("All changes have been reset"), :warning)
    end
    build_ae_tree(:automate, :automate_tree)
    replace_right_cell
  end

  def copy_cancel
    assert_privileges(@sb[:action])
    @record = session[:edit][:typ].find_by(:id => session[:edit][:rec_id])
    model = @edit[:selected_items].count > 1 ? :models : :model
    @sb[:action] = session[:edit] = nil # clean out the saved info
    add_flash(_("Copy %{record} was cancelled by the user") % {:record => ui_lookup(model => @edit[:typ].to_s)})
    @in_a_form = false
    replace_right_cell
  end

  def copy_objects_edit_screen(typ, ids, button_pressed)
    domains = {}
    selected_items = {}
    ids.each_with_index do |id, i|
      record = find_record_with_rbac(typ, from_cid(id))
      selected_items[record.id] = record.display_name.blank? ? record.name : "#{record.display_name} (#{record.name})"
      @record = record if i.zero?
    end
    current_tenant.editable_domains.collect { |domain| domains[domain.id] = domain_display_name(domain) }
    initialize_copy_edit_vars(typ, button_pressed, domains, selected_items)
    @sb[:domain_id] = domains.first.first
    @edit[:current] = copy_hash(@edit[:new])
    model = @edit[:selected_items].count > 1 ? :models : :model
    @right_cell_text = _("Copy %{model}") % {:model => ui_lookup(model => typ.to_s)}
    session[:edit] = @edit
  end

  def initialize_copy_edit_vars(typ, button_pressed, domains, selected_items)
    @edit = {
      :typ            => typ,
      :action         => button_pressed,
      :domain_name    => @record.domain.name,
      :domain_id      => @record.domain.id,
      :old_name       => @record.name,
      :fqname         => @record.fqname,
      :rec_id         => from_cid(@record.id),
      :key            => "copy_objects__#{from_cid(@record.id)}",
      :domains        => domains,
      :selected_items => selected_items,
      :namespaces     => {}
    }
    @edit[:new] = {
      :domain            => domains.first.first,
      :override_source   => true,
      :namespace         => nil,
      :new_name          => nil,
      :override_existing => false
    }
  end

  def create_action_url(node)
    if @sb[:action] == "miq_ae_domain_priority_edit"
      'domains_priority_edit'
    elsif @sb[:action] == 'miq_ae_field_seq'
      'fields_seq_edit'
    elsif MIQ_AE_COPY_ACTIONS.include?(@sb[:action])
      'copy_objects'
    else
      prefix = @edit[:rec_id].nil? ? 'create' : 'update'
      if node == 'aec'
        suffix_hash = {
          'instances' => '_instance',
          'methods'   => '_method',
          'props'     => '',
          'schema'    => '_fields'
        }
        suffix = suffix_hash[@sb[:active_tab]]
      else
        suffix_hash = {
          'root' => '_ns',
          'aei'  => '_instance',
          'aem'  => '_method',
          'aen'  => @edit.key?(:ae_class_id) ? '' : '_ns'
        }
        suffix = suffix_hash[node]
      end
      prefix + suffix
    end
  end

  def get_rec_name(rec)
    column = rec.display_name.blank? ? :name : :display_name
    if rec.kind_of?(MiqAeNamespace) && rec.domain?
      editable_domain = editable_domain?(rec)
      enabled_domain  = rec.enabled
      unless editable_domain && enabled_domain
        return add_read_only_suffix(rec.send(column), editable_domain?(rec), enabled_domain)
      end
    end
    rec.send(column)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deleteclasses
    assert_privileges("miq_ae_class_delete")
    delete_namespaces_or_classes
  end

  # Common aeclasses button handler routines
  def process_aeclasses(aeclasses, task)
    process_elements(aeclasses, MiqAeClass, task)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deleteinstances
    assert_privileges("miq_ae_instance_delete")
    aeinstances = []
    @sb[:row_selected] = find_checked_items
    if @sb[:row_selected]
      @sb[:row_selected].each do |items|
        item = items.split('-')
        item = find_id_with_rbac(MiqAeInstance, from_cid(item[1]))
        aeinstances.push(from_cid(item[1]))
      end
    else
      node = x_node.split('-')
      aeinstances.push(from_cid(node[1]))
      inst = find_record_with_rbac(MiqAeInstance, from_cid(node[1]))
      self.x_node = "aec-#{to_cid(inst.class_id)}"
    end

    process_aeinstances(aeinstances, "destroy") unless aeinstances.empty?
    replace_right_cell(:replace_trees => [:ae])
  end

  # Common aeclasses button handler routines
  def process_aeinstances(aeinstances, task)
    process_elements(aeinstances, MiqAeInstance, task)
  end

  # Delete all selected or single displayed aeclasses(s)
  def deletemethods
    assert_privileges("miq_ae_method_delete")
    aemethods = []
    @sb[:row_selected] = find_checked_items
    if @sb[:row_selected]
      @sb[:row_selected].each do |items|
        item = items.split('-')
        item = find_id_with_rbac(MiqAeMethod, from_cid(item[1]))
        aemethods.push(from_cid(item[1]))
      end
    else
      node = x_node.split('-')
      aemethods.push(from_cid(node[1]))
      inst = find_record_with_rbac(MiqAeMethod, from_cid(node[1]))
      self.x_node = "aec-#{to_cid(inst.class_id)}"
    end

    process_aemethods(aemethods, "destroy") unless aemethods.empty?
    replace_right_cell(:replace_trees => [:ae])
  end

  # Common aeclasses button handler routines
  def process_aemethods(aemethods, task)
    process_elements(aemethods, MiqAeMethod, task)
  end

  def delete_domain
    assert_privileges("miq_ae_domain_delete")
    aedomains = []
    git_domains = []
    if params[:id]
      aedomains.push(params[:id])
      self.x_node = "root"
    else
      selected = find_checked_items
      selected_ids = selected.map { |x| from_cid(x.split('-')[1]) }
      # TODO: replace with RBAC safe method #14665 is merged
      domains = MiqAeDomain.where(:id => selected_ids)
      domains.each do |domain|
        if domain.editable_properties?
          domain.git_enabled? ? git_domains.push(domain) : aedomains.push(domain.id)
        else
          add_flash(_("Read Only Automate Domain \"%{name}\" cannot be deleted") %
            {:name => get_record_display_name(domain)}, :error)
        end
      end
    end
    process_elements(aedomains, MiqAeDomain, 'destroy') unless aedomains.empty?
    git_domains.each do |domain|
      process_element_destroy_via_queue(domain, domain.class, domain.name)
    end
    replace_right_cell(:replace_trees => [:ae])
  end

  # Delete all selected or single displayed aeclasses(s)
  def delete_ns
    assert_privileges("miq_ae_namespace_delete")
    delete_namespaces_or_classes
  end

  def delete_namespaces_or_classes
    selected = find_checked_items
    ae_ns = []
    ae_cs = []
    node = x_node.split('-')
    if params[:id] && params[:miq_grid_checks].blank? && node.first == "aen"
      ae_ns.push(params[:id])
      ns = find_record_with_rbac(MiqAeNamespace, from_cid(node[1]))
      self.x_node = ns.parent_id ? "aen-#{to_cid(ns.parent_id)}" : "root"
    elsif selected
      ae_ns, ae_cs = items_to_delete(selected)
    else
      ae_cs.push(from_cid(node[1]))
      cls = find_record_with_rbac(MiqAeClass, from_cid(node[1]))
      self.x_node = "aen-#{to_cid(cls.namespace_id)}"
    end
    process_ae_ns(ae_ns, "destroy")     unless ae_ns.empty?
    process_aeclasses(ae_cs, "destroy") unless ae_cs.empty?
    replace_right_cell(:replace_trees => [:ae])
  end

  def items_to_delete(selected)
    ns_list = []
    cs_list = []
    selected.each do |items|
      item = items.split('-')
      if item[0] == "aen"
        record = find_record_with_rbac(MiqAeNamespace, from_cid(item[1]))
        if (record.domain? && record.editable_properties?) || record.editable?
          ns_list.push(from_cid(item[1]))
        else
          add_flash(_("\"%{field}\" Automate Domain cannot be deleted") %
                      {:field => get_record_display_name(record)},
                    :error)
        end
      else
        cs_list.push(from_cid(item[1]))
      end
    end
    return ns_list, cs_list
  end

  # Common aeclasses button handler routines
  def process_ae_ns(ae_ns, task)
    process_elements(ae_ns, MiqAeNamespace, task)
  end

  # Get variables from edit form
  def get_form_vars
    @ae_class = MiqAeClass.find_by(:id => from_cid(@edit[:ae_class_id]))
    # for class add tab
    @edit[:new][:name] = params[:name].blank? ? nil : params[:name] if params[:name]
    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:display_name] = params[:display_name].blank? ? nil : params[:display_name] if params[:display_name]
    @edit[:new][:namespace] = params[:namespace] if params[:namespace]
    @edit[:new][:inherits] = params[:inherits_from] if params[:inherits_from]

    # for class edit tab
    @edit[:new][:name] = params[:cls_name].blank? ? nil : params[:cls_name] if params[:cls_name]
    @edit[:new][:description] = params[:cls_description].blank? ? nil : params[:cls_description] if params[:cls_description]
    @edit[:new][:display_name] = params[:cls_display_name].blank? ? nil : params[:cls_display_name] if params[:cls_display_name]
    @edit[:new][:namespace] = params[:cls_namespace] if params[:cls_namespace]
    @edit[:new][:inherits] = params[:cls_inherits_from] if params[:cls_inherits_from]
  end

  # Common routine to find checked items on a page (checkbox ids are "check_xxx" where xxx is the item id or index)
  def find_checked_items(_prefix = nil)
    # AE can't use ApplicationController#find_checked_items because that one expects non-prefixed ids
    params[:miq_grid_checks].split(",") unless params[:miq_grid_checks].blank?
  end

  def field_attributes
    %w(aetype class_id collect datatype default_value description
       display_name id max_retries max_time message name on_entry
       on_error on_exit priority substitute)
  end

  def row_selected_in_grid?
    @sb[:row_selected] || x_node.split('-').first == "aec"
  end
  helper_method :row_selected_in_grid?

  # Get variables from edit form
  def fields_get_form_vars
    @ae_class = MiqAeClass.find_by(:id => from_cid(@edit[:ae_class_id]))
    @in_a_form = true
    @in_a_form_fields = true
    if params[:item].blank? && !%w(accept save).include?(params[:button]) && params["action"] != "field_delete"
      field_data = session[:field_data]
      new_field = @edit[:new_field]

      field_attributes.each do |field|
        field_name = "field_#{field}".to_sym
        field_sym = field.to_sym
        if field == "substitute"
          field_data[field_sym] = new_field[field_sym] = params[field_name] == "1" if params[field_name]
        elsif params[field_name]
          field_data[field_sym] = new_field[field_sym] = params[field_name]
        end
      end

      field_data[:default_value] = new_field[:default_value] = params[:field_password_value] if params[:field_password_value]
      new_field[:priority] = 1
      @edit[:new][:fields].each_with_index do |flds, i|
        if i == @edit[:new][:fields].length - 1
          new_field[:priority] = flds['priority'].nil? ? 1 : flds['priority'].to_i + 1
        end
      end
      new_field[:class_id] = @ae_class.id

      @edit[:new][:fields].each_with_index do |fld, i|
        field_attributes.each do |field|
          field_name = "fields_#{field}_#{i}"
          if field == "substitute"
            fld[field] = params[field_name] == "1" if params[field_name]
          elsif %w(aetype datatype).include?(field)
            var_name = "fields_#{field}#{i}"
            fld[field] = params[var_name.to_sym] if params[var_name.to_sym]
          elsif field == "default_value"
            fld[field] = params[field_name] if params[field_name]
            fld[field] = params["fields_password_value_#{i}".to_sym] if params["fields_password_value_#{i}".to_sym]
          elsif params[field_name]
            fld[field] = params[field_name]
          end
        end
      end
    elsif params[:button] == "accept"
      if session[:field_data][:name].blank? || session[:field_data][:aetype].blank?
        field = session[:field_data][:name].blank? ? "Name" : "Type"
        field += " and Type" if field == "Name" && session[:field_data][:aetype].blank?
        add_flash(_("%{field} is required") % {:field => field}, :error)
        return
      end
      new_fields = {}
      field_attributes.each do |field_attribute|
        new_fields[field_attribute] = @edit[:new_field][field_attribute.to_sym]
      end
      @edit[:new][:fields].push(new_fields)
      @edit[:new_field] = session[:field_data] = {}
    end
  end

  def method_form_vars_process_fields(prefix = '')
    @edit[:new][:fields].each_with_index do |field, i|
      method_input_column_names.each do |column|
        field[column] = params["#{prefix}fields_#{column}_#{i}".to_sym] if params["#{prefix}fields_#{column}_#{i}".to_sym]

        next unless column == 'default_value'
        field[column] = params["#{prefix}fields_value_#{i}".to_sym] if params["#{prefix}fields_value_#{i}".to_sym]
        field[column] = params["#{prefix}fields_password_value_#{i}".to_sym] if params["#{prefix}fields_password_value_#{i}".to_sym]
      end
    end
  end

  # Get variables from edit form
  def get_method_form_vars
    @ae_method = @edit[:ae_method_id] ? MiqAeMethod.find(from_cid(@edit[:ae_method_id])) : MiqAeMethod.new
    @in_a_form = true
    if params[:item].blank? && params[:button] != "accept" && params["action"] != "field_delete"
      # for method_inputs view
      @edit[:new][:name] = params[:method_name].blank? ? nil : params[:method_name] if params[:method_name]
      @edit[:new][:display_name] = params[:method_display_name].blank? ? nil : params[:method_display_name] if params[:method_display_name]
      @edit[:new][:location] = params[:method_location] if params[:method_location]
      @edit[:new][:location] ||= "inline"
      @edit[:new][:data] = params[:method_data] if params[:method_data]
      method_form_vars_process_fields
      session[:field_data][:name] = @edit[:new_field][:name] = params[:field_name] if params[:field_name]
      session[:field_data][:datatype] = @edit[:new_field][:datatype] = params[:field_datatype] if params[:field_datatype]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:field_default_value] if params[:field_default_value]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:field_password_value] if params[:field_password_value]

      # for class_methods view
      @edit[:new][:name] = params[:cls_method_name].blank? ? nil : params[:cls_method_name] if params[:cls_method_name]
      @edit[:new][:display_name] = params[:cls_method_display_name].blank? ? nil : params[:cls_method_display_name] if params[:cls_method_display_name]
      @edit[:new][:location] = params[:cls_method_location] if params[:cls_method_location]
      @edit[:new][:location] ||= "inline"
      @edit[:new][:data] = params[:cls_method_data] if params[:cls_method_data]
      @edit[:new][:data] += "..." if params[:transOne] && params[:transOne] == "1" # Update the new data to simulate a change
      method_form_vars_process_fields('cls_')
      session[:field_data][:name] = @edit[:new_field][:name] = params[:cls_field_name] if params[:cls_field_name]
      session[:field_data][:datatype] = @edit[:new_field][:datatype] = params[:cls_field_datatype] if params[:cls_field_datatype]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:cls_field_default_value] if params[:cls_field_default_value]
      session[:field_data][:default_value] = @edit[:new_field][:default_value] = params[:cls_field_password_value] if params[:cls_field_password_value]
      @edit[:new_field][:method_id] = @ae_method.id
      session[:field_data] ||= {}
    elsif params[:button] == "accept"
      if @edit[:new_field].blank? || @edit[:new_field][:name].nil? || @edit[:new_field][:name] == ""
        add_flash(_("Name is required"), :error)
        return
      end
      new_field = {}
      new_field['name']          = @edit[:new_field][:name]
      new_field['datatype']      = @edit[:new_field][:datatype]
      new_field['default_value'] = @edit[:new_field][:default_value]
      new_field['method_id']     = @ae_method.id
      @edit[:new][:fields].push(new_field)
      @edit[:new_field] = {
        :name          => '',
        :default_value => '',
        :datatype      => 'string'
      }
    elsif params[:add] == 'new'
      session[:fields_data] = {
        :name          => '',
        :default_value => '',
        :datatype      => 'string'
      }
    end
  end

  # Get variables from edit form
  def get_ns_form_vars
    @ae_ns = @edit[:typ].constantize.find_by(:id => from_cid(@edit[:ae_ns_id]))
    @edit[:new][:enabled] = params[:ns_enabled] == '1' if params[:ns_enabled]
    [:ns_name, :ns_description].each do |field|
      next unless params[field]
      @edit[:new][field] = params[field].blank? ? nil : params[field]
    end
    @in_a_form = true
  end

  def get_instances_form_vars_for(prefix = nil)
    instance_column_names.each do |key|
      @edit[:new][:ae_inst][key] =
        params["#{prefix}inst_#{key}"].blank? ? nil : params["#{prefix}inst_#{key}"] if params["#{prefix}inst_#{key}"]
    end

    @ae_class.ae_fields.sort_by { |a| [a.priority.to_i] }.each_with_index do |_fld, i|
      %w(value collect on_entry on_exit on_error max_retries max_time).each do |key|
        @edit[:new][:ae_values][i][key] = params["#{prefix}inst_#{key}_#{i}".to_sym] if params["#{prefix}inst_#{key}_#{i}".to_sym]
      end
      @edit[:new][:ae_values][i]["value"] = params["#{prefix}inst_password_value_#{i}".to_sym] if params["#{prefix}inst_password_value_#{i}".to_sym]
    end
  end

  # Get variables from edit form
  def get_instances_form_vars
    # resetting inst/class/values from id stored in @edit.
    @ae_inst   = @edit[:ae_inst_id] ? MiqAeInstance.find(@edit[:ae_inst_id]) : MiqAeInstance.new
    @ae_class  = MiqAeClass.find(from_cid(@edit[:ae_class_id]))
    @ae_values = @ae_class.ae_fields.sort_by { |a| a.priority.to_i }.collect do |fld|
      MiqAeValue.find_or_initialize_by(:field_id => fld.id.to_s, :instance_id => @ae_inst.id.to_s)
    end

    if x_node.split('-').first == "aei"
      # for instance_fields view
      get_instances_form_vars_for
    else
      # for class_instances view
      get_instances_form_vars_for("cls_")
    end
  end

  # Set record variables to new values
  def set_record_vars(miqaeclass)
    miqaeclass.name = @edit[:new][:name].strip unless @edit[:new][:name].blank?
    miqaeclass.display_name = @edit[:new][:display_name]
    miqaeclass.description = @edit[:new][:description]
    miqaeclass.inherits = @edit[:new][:inherits]
    ns = x_node.split("-")
    if ns.first == "aen" && !miqaeclass.namespace_id
      rec = MiqAeNamespace.find(from_cid(ns[1]))
      miqaeclass.namespace_id = rec.id.to_s
      # miqaeclass.namespace = rec.name
    end
  end

  # Set record variables to new values
  def set_method_record_vars(miqaemethod)
    miqaemethod.name = @edit[:new][:name].strip unless @edit[:new][:name].blank?
    miqaemethod.display_name = @edit[:new][:display_name]
    miqaemethod.scope = @edit[:new][:scope]
    miqaemethod.location = @edit[:new][:location]
    miqaemethod.language = @edit[:new][:language]
    miqaemethod.data = if @edit[:new][:location] == 'expression'
                         data_for_expression
                       else
                         @edit[:new][:data]
                       end
    miqaemethod.class_id = from_cid(@edit[:ae_class_id])
    miqaemethod.embedded_methods = @edit[:new][:embedded_methods] if @edit[:new][:location] == 'inline'
  end

  # Set record variables to new values
  def ns_set_record_vars(miqaens)
    miqaens.name        = @edit[:new][:ns_name].strip unless @edit[:new][:ns_name].blank?
    miqaens.description = @edit[:new][:ns_description]
    miqaens.enabled     = @edit[:new][:enabled] if miqaens.domain?
  end

  # Set record variables to new values
  def set_field_vars(parent = nil)
    fields = parent_fields(parent)
    highest_priority = fields.count
    @edit[:new][:fields].each_with_index do |fld, i|
      if fld["id"].nil?
        new_field = MiqAeField.new
        highest_priority += 1
        new_field.priority = highest_priority
        if @ae_method
          new_field.method_id = @ae_method.id
        else
          new_field.class_id = @ae_class.id
        end
      else
        new_field = parent.nil? ? MiqAeField.find(fld["id"]) : fields.detect { |f| f.id == fld["id"] }
      end

      field_attributes.each do |attr|
        if attr == "substitute" || @edit[:new][:fields][i][attr]
          new_field.send("#{attr}=", @edit[:new][:fields][i][attr])
        end
      end
      if new_field.new_record? || parent.nil?
        raise StandardError, new_field.errors.full_messages[0] unless fields.push(new_field)
      end
    end
    reset_field_priority(fields)
  end
  alias_method :set_input_vars, :set_field_vars

  def parent_fields(parent)
    return [] unless parent
    parent.class == MiqAeClass ? parent.ae_fields : parent.inputs
  end

  def reset_field_priority(fields)
    # reset priority to be in order 1..3
    i = 0
    fields.sort_by { |a| [a.priority.to_i] }.each do |fld|
      if !@edit[:fields_to_delete].include?(fld.id.to_s) || fld.id.blank?
        i += 1
        fld.priority = i
      end
    end
    fields
  end

  # Set record variables to new values
  def set_instances_record_vars(miqaeinst)
    instance_column_names.each do |attr|
      miqaeinst.send("#{attr}=", @edit[:new][:ae_inst][attr].try(:strip))
    end
    miqaeinst.class_id = from_cid(@edit[:ae_class_id])
  end

  # Set record variables to new values
  def set_instances_value_vars(vals, ae_instance = nil)
    original_values = ae_instance ? ae_instance.ae_values : []

    vals.each_with_index do |v, i|
      original = original_values.detect { |ov| ov.id == v.id } unless original_values.empty?
      if original
        v = original
      elsif ae_instance
        ae_instance.ae_values << v
      end
      value_column_names.each do |attr|
        v.send("#{attr}=", @edit[:new][:ae_values][i][attr]) if @edit[:new][:ae_values][i][attr]
      end
    end
  end

  def fields_seq_edit_screen(id)
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}
    @ae_class = MiqAeClass.find_by(:id => from_cid(id))
    @edit[:rec_id] = @ae_class.try(:id)
    @edit[:ae_class_id] = @ae_class.id
    @edit[:new][:fields] = @ae_class.ae_fields.to_a.deep_clone
    @edit[:new][:fields_list] = @edit[:new][:fields]
                                .sort_by { |f| f.priority.to_i }
                                .collect { |f| f.display_name ? "#{f.display_name} (#{f.name})" : "(#{f.name})" }
    @edit[:key] = "fields_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])
    @right_cell_text = _("Edit of Class Schema Sequence '%{name}'") % {:name => @ae_class.name}
    session[:edit] = @edit
  end

  def move_selected_fields_up(available_fields, selected_fields, display_name)
    if no_items_selected?(selected_fields)
      add_flash(_("No %{name} were selected to move up") % {:name => display_name}, :error)
      return false
    end

    consecutive, first_idx, last_idx = selected_consecutive?(available_fields, selected_fields)
    @selected = selected_fields

    if consecutive
      if first_idx > 0
        available_fields[first_idx..last_idx].reverse_each do |field|
          pulled = available_fields.delete(field)
          available_fields.insert(first_idx - 1, pulled)
        end
      end
      return true
    end

    add_flash(_("Select only one or consecutive %{name} to move up") % {:name => display_name}, :error)
    false
  end

  def move_selected_fields_down(available_fields, selected_fields, display_name)
    if no_items_selected?(selected_fields)
      add_flash(_("No %{name} were selected to move down") % {:name => display_name}, :error)
      return false
    end

    consecutive, first_idx, last_idx = selected_consecutive?(available_fields, selected_fields)
    @selected = selected_fields

    if consecutive
      if last_idx < available_fields.length - 1
        insert_idx = last_idx + 1 # Insert before the element after the last one
        insert_idx = -1 if last_idx == available_fields.length - 2 # Insert at end if 1 away from end
        available_fields[first_idx..last_idx].each do |field|
          pulled = available_fields.delete(field)
          available_fields.insert(insert_idx, pulled)
        end
      end
      return true
    end

    add_flash(_("Select only one or consecutive %{name} to move down") % {:name => display_name}, :error)
    false
  end

  def no_items_selected?(field_name)
    !field_name || field_name.empty? || field_name[0] == ""
  end

  def selected_consecutive?(available_fields, selected_fields)
    first_idx = last_idx = 0
    available_fields.each_with_index do |nf, idx|
      first_idx = idx if nf == selected_fields.first
      if nf == selected_fields.last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > selected_fields.length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  def edit_domain_or_namespace
    obj = find_checked_items
    obj = [x_node] if obj.nil? && params[:id]
    typ = params[:pressed] == "miq_ae_domain_edit" ? MiqAeDomain : MiqAeNamespace
    @ae_ns = find_record_with_rbac(typ, from_cid(obj[0].split('-')[1]))
    if @ae_ns.domain? && !@ae_ns.editable_properties?
      add_flash(_("Read Only Automate Domain \"%{name}\" cannot be edited") %
                  {:name => get_record_display_name(@ae_ns)},
                :error)
    else
      ns_set_form_vars
      @in_a_form = true
      session[:changed] = @changed = false
    end
    replace_right_cell
  end

  def new_ns
    assert_privileges("miq_ae_namespace_new")
    new_domain_or_namespace(MiqAeNamespace)
  end

  def new_domain
    assert_privileges("miq_ae_domain_new")
    new_domain_or_namespace(MiqAeDomain)
  end

  def new_domain_or_namespace(klass)
    parent_id = x_node == "root" ? nil : from_cid(x_node.split("-").last)
    @ae_ns = klass.new(:parent_id => parent_id)
    ns_set_form_vars
    @in_a_form = true
    replace_right_cell
  end

  # Set form variables for edit
  def ns_set_form_vars
    session[:field_data] = session[:edit] = {}
    @edit = {
      :ae_ns_id => @ae_ns.id,
      :typ      => @ae_ns.domain? ? "MiqAeDomain" : "MiqAeNamespace",
      :key      => "aens_edit__#{@ae_ns.id || "new"}",
      :rec_id   => @ae_ns.id || nil
    }
    @edit[:new] = {
      :ns_name        => @ae_ns.name,
      :ns_description => @ae_ns.description
    }
    # set these field for a new domain or when existing record is a domain
    @edit[:new][:enabled] = @ae_ns.enabled if @ae_ns.domain?
    @edit[:current] = @edit[:new].dup
    @right_cell_text = ns_right_cell_text
    session[:edit] = @edit
  end

  def ns_right_cell_text
    model = ui_lookup(:model => @edit[:typ])
    name_for_msg = if @edit[:rec_id].nil?
                     _("Adding a new %{model}") % {:model => model}
                   else
                     _("Editing %{model} \"%{name}\"") % {:model => model, :name => @ae_ns.name}
                   end
    name_for_msg
  end

  def ordered_domains_for_priority_edit_screen
    User.current_tenant.sequenceable_domains.collect(&:name)
  end

  def priority_edit_screen
    @in_a_form = true
    @edit = {
      :key => "priority__edit",
      :new => {:domain_order => ordered_domains_for_priority_edit_screen}
    }
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit]  = @edit
  end

  def domain_toggle(locked)
    assert_privileges("miq_ae_domain_#{locked ? 'lock' : 'unlock'}")
    action = locked ? _("Locked") : _("Unlocked")
    if params[:id].nil?
      add_flash(_("No Automate Domain were selected to be marked as %{action}") % {:action => action}, :error)
      javascript_flash
    end
    domain_toggle_lock(params[:id], locked)
    unless flash_errors?
      add_flash(_("The selected Automate Domain were marked as %{action}") % {:action => action}, :info, true)
    end
    replace_right_cell(:replace_trees => [:ae])
  end

  def domain_lock
    domain_toggle(true)
  end

  def domain_unlock
    domain_toggle(false)
  end

  def domain_toggle_lock(domain_id, lock)
    domain = MiqAeDomain.find(domain_id)
    lock ? domain.lock_contents! : domain.unlock_contents!
  end

  def git_refresh
    @in_a_form = true
    @explorer = true

    session[:changed] = true

    git_repo = MiqAeDomain.find(params[:id]).git_repository

    git_based_domain_import_service.refresh(git_repo.id)

    git_repo.reload
    @branch_names = git_repo.git_branches.collect(&:name)
    @tag_names = git_repo.git_tags.collect(&:name)
    @git_repo_id = git_repo.id
    @right_cell_text = _("Refreshing branch/tag for Git-based Domain")

    h_tb = build_toolbar("x_history_tb")

    presenter = ExplorerPresenter.new(
      :active_tree     => x_active_tree,
      :right_cell_text => @right_cell_text,
      :remove_nodes    => nil,
      :add_nodes       => nil,
    )

    update_partial_div = :main_div
    update_partial = "git_domain_refresh"

    presenter.update(update_partial_div, r[:partial => update_partial])

    action_url = "refresh_git_domain"
    presenter.show(:paging_div, :form_buttons_div)
    presenter.update(:form_buttons_div, r[
      :partial => "layouts/x_edit_buttons",
      :locals  => {
        :record_id  => git_repo.id,
        :action_url => action_url,
        :serialize  => true,
        :no_reset   => true
      }
    ])

    presenter.reload_toolbars(:history => h_tb)
    presenter.show(:toolbar)

    render :json => presenter.for_render
  end

  def git_based_domain_import_service
    @git_based_domain_import_service ||= GitBasedDomainImportService.new
  end

  def get_instance_node_info(id)
    begin
      @record = MiqAeInstance.find(from_cid(id[1]))
    rescue ActiveRecord::RecordNotFound
      set_root_node
      return
    end

    @ae_class = @record.ae_class
    @sb[:active_tab] = "instances"
    domain_overrides
    set_right_cell_text(x_node, @record)
  end

  def get_method_node_info(id)
    begin
      @record = @ae_method = MiqAeMethod.find(from_cid(id[1]))
    rescue ActiveRecord::RecordNotFound
      set_root_node
      return
    end

    @ae_class = @record.ae_class
    @sb[:squash_state] = true
    @sb[:active_tab] = "methods"
    if @record.location == 'expression'
      hash = YAML.load(@record.data)
      @expression = hash[:expression] ? MiqExpression.new(hash[:expression]).to_human : ""
    elsif @record.location == "playbook"
      fetch_playbook_details
    end
    domain_overrides
    set_right_cell_text(x_node, @record)
  end

  def fetch_playbook_details
    @playbook_details = {}
    options = @record.options
    @playbook_details[:repository] = fetch_name_from_object(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource, options[:repository_id])
    @playbook_details[:playbook] = fetch_name_from_object(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook, options[:playbook_id])
    @playbook_details[:machine_credential] = fetch_name_from_object(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential, options[:credential_id])
    @playbook_details[:network_credential] = fetch_name_from_object(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential, options[:network_credential_id]) if options[:network_credential_id]
    @playbook_details[:cloud_credential] = fetch_name_from_object(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential, options[:cloud_credential_id]) if options[:cloud_credential_id]
    @playbook_details[:verbosity] = options[:verbosity]
    @playbook_details[:become_enabled] = options[:become_enabled] == true ? _("Yes") : _("No")
    @playbook_details
  end

  def get_class_node_info(id)
    @sb[:active_tab] = "instances" if !@in_a_form && !params[:button] && !params[:pressed]
    begin
      @record = @ae_class = MiqAeClass.find(from_cid(id[1]))
    rescue ActiveRecord::RecordNotFound
      set_root_node
      return
    end

    @combo_xml = build_type_options
    # passing fields because that's how many combo boxes we need
    @dtype_combo_xml = build_dtype_options
    @grid_methods_list_xml = build_details_grid(@record.ae_methods)
    domain_overrides
    set_right_cell_text(x_node, @record)
  end

  def domain_overrides
    @domain_overrides = {}
    typ, = x_node.split('-')
    overrides = TreeBuilder.get_model_for_prefix(typ).constantize.get_homonymic_across_domains(current_user, @record.fqname)
    overrides.each do |obj|
      display_name, id = domain_display_name_using_name(obj, @record.domain.name)
      @domain_overrides[display_name] = id
    end
  end

  def title
    _("Datastore")
  end

  def session_key_prefix
    "miq_ae_class"
  end

  def get_session_data
    super
    @edit = session[:edit]
  end

  def flash_validation_errors(am_obj)
    am_obj.errors.each do |field, msg|
      add_flash("#{field.to_s.capitalize} #{msg}", :error)
    end
  end

  menu_section :automate

  def process_element_destroy_via_queue(element, klass, name)
    return unless element.respond_to?(:destroy)

    audit = {:event        => "#{klass.name.downcase}_record_delete",
             :message      => "[#{name}] Record deleted",
             :target_id    => element.id,
             :target_class => klass.base_class.name,
             :userid       => session[:userid]}

    model_name  = ui_lookup(:model => klass.name) # Lookup friendly model name in dictionary
    record_name = get_record_display_name(element)

    begin
      git_based_domain_import_service.destroy_domain(element.id)
      AuditEvent.success(audit)
      add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => model_name, :name => record_name})
    rescue => bang
      add_flash(_("%{model} \"%{name}\": Error during delete: %{error_msg}") %
               {:model => model_name, :name => record_name, :error_msg => bang.message}, :error)
    end
  end
end
