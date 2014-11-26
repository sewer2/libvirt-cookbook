

def load_current_resource
  @current_resource = Chef::Resource::LibvirtDomain.new(new_resource.name)
  @libvirt = ::Libvirt.open('qemu:///system')
  @domain  = load_domain rescue nil
  @current_resource
end

action :define do
  require 'uuidtools'
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
  end
end

private

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
