Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"

  config.vm.provider "virtualbox" do |v|
    v.memory = 512
    v.cpus = 1
  end

  config.vm.define "selinux" do |selinux|
    selinux.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    selinux.vm.hostname = "selinux"
    selinux.vm.provision "shell", path: "scripts/selinux.sh"
  end
end