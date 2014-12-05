

def load_current_resource
  @current_resource = Chef::Resource::LibvirtDomain.new(new_resource.name)
  @libvirt = ::Libvirt.open('qemu:///system')
  @domain  = load_domain rescue nil
  @current_resource
end

action :define do
  unless domain_defined?
    domain_uuid = ''
    define_domain(domain_uuid)
  else
    @domain.undefine
    domain_uuid = @domain.uuid
    define_domain(domain_uuid)
  end
  new_resource.updated_by_last_action(true)
end

action :create do
  require_defined_domain
  unless domain_active?
    @domain.create
    @domain.autostart = new_resource.autostart
    new_resource.updated_by_last_action(true)
  end
end

private

def define_domain(domain_uuid)
  uuid = domain_uuid
  domain_xml = Tempfile.new(new_resource.name)
  config = create_xml(new_resource.conf_mash)
  t = template domain_xml.path do
    cookbook "libvirt"
    source   "kvm_domain.erb"
    variables(
      :name => new_resource.name,
      :uuid => uuid,
      :conf_xml => config
    )
    action :nothing
  end
  t.run_action(:create)
  @libvirt.define_domain_xml(::File.read(domain_xml.path))
  @domain = load_domain
  reautostart_domain
end

def reautostart_domain
  auto = new_resource.autostart
  @domain.autostart = false
  @domain.autostart = true if auto
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

def domain_active?
  @domain.active?
end
