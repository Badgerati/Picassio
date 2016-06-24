Vagrant.configure("2") do |config|
    config.vm.box = "opentable/win-2012r2-standard-amd64-nocm"
    config.vm.guest = :windows
    config.vm.communicator = "winrm"

    config.vm.provider "virtualbox" do |vb|
        vb.gui = true
        vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    end

    config.vm.provision "shell" do |s|
        s.inline = "winrm quickconfig"
    end

    config.vm.provision "shell" do |s|
        s.inline = "cd c:/vagrant/src; ./picassio.ps1 -reinstall"
        s.keep_color = true
    end

    config.vm.provision "shell" do |s|
        s.inline = "cd c:/vagrant/tests; picassio -paint"
        s.keep_color = true
    end
end
