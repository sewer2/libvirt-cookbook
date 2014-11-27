

def load_current_resource
  @current_resource = Chef::Resource::LibvirtDomain.new(new_resource.name)
  @libvirt = ::Libvirt.open('qemu:///system')
  @domain  = load_domain rescue nil
  @current_resource
end

action :define do
  unless domain_defined?
    domain_xml = Tempfile.new(new_resource.name)
    config = create_xml(new_resource.conf_mash)
    t = template domain_xml.path do
      cookbook "libvirt"
      source   "kvm_domain.erb"
      variables(
        :name => new_resource.name,
        :conf_xml => config
      )
      action :nothing
    end
    t.run_action(:create)

    @libvirt.define_domain_xml(::File.read(domain_xml.path))
    @domain = load_domain
    new_resource.updated_by_last_action(true)
  end
end

action :autostart do
  require_defined_domain
  unless domain_autostart?
    @domain.autostart = true
    new_resource.updated_by_last_action(true)
  end
end

action :create do
  require_defined_domain
  unless domain_active?
    @domain.create
    new_resource.updated_by_last_action(true)
  else
    config = new_resource.conf_mash
    config['devices'].each do |dev, opt|
      if opt.is_a?(Array)
        opt.each do |o|
          update_domain_devices({dev=>o})
        end
      else
        update_domain_devices({dev=>opt})
      end
    end
    new_resource.updated_by_last_action(true)
  end
end

private

def update_domain_devices(device)
  device_xml = Tempfile.new(new_resource.name+"_device"+device.keys[0])
  t = template device_xml.path do
    cookbook "libvirt"
    source   "kvm_devices.erb"
    variables(
      :conf_xml => create_xml(device)
    )
    action :nothing
  end
  t.run_action(:create)
  @domain.update_device(::File.read(device_xml.path))
rescue
  Chef::Log.info("live update of device #{device.keys[0]} is not supported")
end

def load_domain
  @libvirt.lookup_domain_by_name(new_resource.name)
end

def require_defined_domain
  error = RuntimeError.new "You have to define libvirt domain '#{new_resource.name}' first"
  raise error unless domain_defined?
end

def domain_defined?
  @domain
end

def domain_autostart?
  @domain.autostart?
end

def domain_active?
  @domain.active?
end
