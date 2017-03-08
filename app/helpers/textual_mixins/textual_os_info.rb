module TextualMixins::TextualOsInfo
  def textual_osinfo
    h = {:label => _("Operating System")}
    product_name = @record.product_name
    if product_name.blank?
      os_image_name = @record.os_image_name
      if os_image_name.blank?
        h[:value] = _("Unknown")
      else
        h[:image] = "svg/os-#{os_image_name.downcase}.svg"
        h[:value] = os_image_name
      end
    else
      h[:image] = "svg/os-#{@record.os_image_name.downcase}.svg"
      h[:value] = product_name
      h[:title] = _("Show OS container information")
      h[:explorer] = true
      h[:link] = url_for_only_path(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end
end
