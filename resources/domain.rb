actions :define, :create, :autostart

def initialize(*args)
  super
  @action = :define
end

attribute :conf_mash, :kind_of => Hash, :required => true
attribute :autostart, :kind_of => [TrueClass, FalseClass], :default => false