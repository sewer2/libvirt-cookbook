run_context = Chef::RunContext.new(Chef::Node.new, {}, Chef::EventDispatch::Dispatcher.new)
chef_gem = Chef::Resource::ChefGem.new("builder", run_context)
chef_gem.run_action(:install)

require 'builder/xmlmarkup'

class MyXmlMarkup < Builder::XmlMarkup
  def insert_attributes(attrs, order=[])
      return if attrs.nil?
      order.each do |k|
        v = attrs[k]
        @target << %{ #{k}=#{@quote}#{_attr_value(v)}#{@quote}} if v
      end
      attrs.each do |k, v|
        @target << %{ #{k}=#{@quote}#{_attr_value(v)}#{@quote}} unless order.member?(k) # " WART
      end
  end
  def insert_text(text)
    @target << text
  end
  def start_tag(sym, attrs, end_too=false)
    @target << "<#{sym}"
    _insert_attributes(attrs)
    @target << "/" if end_too
    @target << ">"
  end
  def end_tag(sym)
    @target << "</#{sym}>"
  end
end

def indent_tag(xml, indent, level)
  return if indent == 0 || level == 0
  xml.insert_text(" " * (level * indent))
end

def newline_tag(xml,indent)
    return if indent == 0
     xml.insert_text("\n")
end


def to_xml(data, xm, indent=2, level=0)
  if data.is_a?(Array)
    data.each do |t|
      to_xml(t,xm,indent,level)
    end
  else
    data.each do |t,params|
      attr={}
      child=[]
      value=''
      if params.is_a?(String)
        value=params
      elsif params.is_a?(Array)
        params.each do |a|
          to_xml({t=>a},xm, indent,level)
        end
        next
      else
        params.each do |k, v|
          attr[k[1,k.size]] = v if k[0]=='-'
          value = v if k == "#text"
          child << {k=>v} if v.is_a?(Hash)
          if v.is_a?(Array)
            v.each do |kid|
              child << {k=>kid}
            end
          end
        end
      end
      if child.empty?
       indent_tag(xm, indent, level)
       xm.start_tag(t, attr, value.empty?)
       xm.insert_text(value)
       xm.end_tag(t) unless value.empty?
      else
        indent_tag(xm,indent, level)
        xm.start_tag(t, attr)
        newline_tag(xm, indent)
        kids_level=level+1
        to_xml(child,xm, indent, kids_level)
        unless value.empty?
          indent_tag(xm, indent, kids_level)
          xm.insert_text(value)
          newline_tag(xm, indent)
        end
        indent_tag(xm, indent, level)
        xm.end_tag(t)
      end
      newline_tag(xm, indent)
    end
  end
end

def create_xml(array)
xm=MyXmlMarkup.new
to_xml(array,xm,2,2)
x=xm.to_s.chomp("<to_s/>")
return x if x
return xm.to_s
end
