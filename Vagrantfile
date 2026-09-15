Vagrant.configure("2") do |config|
  config.vm.define "windows" do |windows|
    windows.vm.box = "gusztavvargadr/windows-10"
    windows.vm.communicator = "winssh"
    windows.vm.boot_timeout = 1800
    windows.vm.synced_folder ".", "/Users/vagrant/scoop/apps/scoop/current"
  end
end
