module PhysicalServerHelper::TextualSummary


  def textual_group_properties
    %i(name model productName manufacturer  machineType serialNumber  uuid)
  end

  def textual_group_relationships
    %i(host)
  end

  def textual_group_compliance

  end


  def textual_host
    # The host / physical server relationship is currently broken in the
    # database. This causes the value of @record.host to be nil, so when
    # a host's service_tag or id attribute is accessed, an undefined method
    # error occurs. To prevent this error, we need to check to see if the
    # record's host is nil, and if it is, we will not attempt to access any
    # of its attributes.
    host_id = nil
    host_service_tag = nil
    if @record.host != nil
      host_id = @record.host.id
      host_service_tag = @record.host.sevice_tag
    end

    {:label => _("Host"), :value => host_service_tag, :link => url_for(:controller =>'host', :action =>  'show', :id =>  host_id)}
  end

  def textual_name
    {:label => _("Server name"), :value => @record.name }
  end

   def textual_productName
     {:label => _("Product Name"), :value => @record.productName }
   end
  
   def textual_manufacturer
     {:label => _("Manufacturer"), :value => @record.manufacturer }
   end
  
  
   def textual_machineType
     {:label =>_("Machine Type"), :value =>  @record.machineType }
   end
  
  
   def textual_serialNumber
     {:label => _("Serial Number"), :value => @record.serialNumber }
   end
  
   def textual_uuid
     {:label => _("UUID"), :value => @record.uuid }
  
   end

   def textual_model
      {:label =>  _("Model"), :value  =>  @record.model}
   end
    
end
