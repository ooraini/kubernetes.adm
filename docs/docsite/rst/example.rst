.. _ansible_collections.kubernetes.adm.docsite.example:

Full Example with Vagrant
=========================

See requirements in :ref:`ansible_collections.kubernetes.adm.docsite.requirements`.

- Six node cluster
- Three control plane and three worker nodes
- Using vagrant with libvirt provider
- HAProxy distributed load balancer
- Cilium as CNI plugin


Vagrantfile
-----------

.. code-block:: ruby

    Vagrant.configure("2") do |config|

      config.vm.synced_folder ".", "/vagrant", disabled: true
      config.ssh.insert_key = false

      config.vm.provider :libvirt do |libvirt|
        libvirt.qemu_use_session = false
      end

      masters = {
        'node1': "192.168.33.10",
        'node2': "192.168.33.20",
        'node3': "192.168.33.30",
      }

      workers = {
        'node4': "192.168.33.40",
        'node5': "192.168.33.50",
        'node6': "192.168.33.60"
      }

      masters.each do |name, ip|
        config.vm.define "#{name}" do |node|
          node.vm.box = "rocky8/kubeadm_1.22.4"
          node.vm.network "private_network", ip: ip
          node.vm.provider :libvirt do |libvirt|
            libvirt.cpus = 2
            libvirt.memory = 4096
          end
        end
      end

      workers.each do |name, ip|
        config.vm.define "#{name}" do |node|
          node.vm.box = "rocky8/kubeadm_1.22.4"
          node.vm.network "private_network", ip: ip
          node.vm.provider :libvirt do |libvirt|
            libvirt.cpus = 4
            libvirt.memory = 8192
            libvirt.storage :file, :size => '20G'
          end
        end
      end

      config.vm.provision "shell" do |s|
        ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
        s.inline = <<-SHELL
          echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
        SHELL
      end
    end


Inventory
---------

.. code-block:: yaml+jinja

    all:
      vars:
        ansible_user: vagrant
      hosts:
        node1:
          ansible_host: '192.168.33.10'
        node2:
          ansible_host: '192.168.33.20'
        node3:
          ansible_host: '192.168.33.30'
        node4:
          ansible_host: '192.168.33.40'
        node5:
          ansible_host: '192.168.33.50'
        node6:
          ansible_host: '192.168.33.60'
      children:
        k8s_control_plane:
          hosts:
            node1:
            node2:
            node3:

        k8s_workers:
          hosts:
            node4:
            node5:
            node6:

        k8s_cluster:
          vars:
            kubernetes_version: "1.22.4"

            kubeadm_apiversion: v1beta3
            kubeadm_skip_phases: ["addon/kube-proxy"]

            cluster_pod_cidr: 172.16.0.0/16
            cluster_service_cidr: 172.17.0.0/16
            control_plane_endpoint: cluster:8443
            control_plane_hostgroup: k8s_control_plane
            swap_state: disabled

            helm_version: '3.7.2'
            cilium_version: '1.11.0'

          children:
            k8s_control_plane:
            k8s_workers:

        k8s_init_node:
          hosts:
            node1


Playbook
--------

.. code-block:: yaml+jinja

    - name: Ensure hostname and /etc/hosts for nodes
      gather_facts: false
      hosts: k8s_cluster
      become: true
      tasks:
        - name: /etc/hosts
          blockinfile:
            path: /etc/hosts
            block: |
              {% for host in groups['k8s_cluster'] %}
              {{hostvars[host].ansible_host }} {{ host }}
              {% endfor %}
              # CLUSTER ENDPOINT
              127.0.0.1 cluster

        - name: Set hostname
          hostname: name="{{ inventory_hostname }}"

        - name: Ensure firewalld is stopped and disabled
          systemd:
            name: firewalld
            state: stopped
            enabled: false

        # To avoid any problem with the CNI disable the mgmt interface. Optional
        - shell: |
            nmcli connection modify 'Wired connection 1' autoconnect false
            nmcli device disconnect eth0
            nmcli connection modify 'System eth1' ipv4.route-metrics 99
            nmcli connection modify 'System eth1' ipv4.gateway 192.168.33.1
            nmcli connection modify 'System eth1' ipv4.dns 8.8.8.8,8.8.4.4
            nmcli connection up 'System eth1'
          become: true
          ignore_errors: true

        - shell: cat /proc/cmdline
          register: kernel_boot
          changed_when: false

        # Optional
        - name: Ensure cgroupv2
          become: true
          when: '"systemd.unified_cgroup_hierarchy=1" not in kernel_boot.stdout'
          block:
            - shell: grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
            - reboot:

    - hosts: k8s_cluster
      roles: [ kubernetes.adm.distributed_lb ]

    - import_playbook: kubernetes.adm.cluster
      vars:
        control_plane_hostgroup: k8s_control_plane
        workers_hostgroup: k8s_workers
        cluster_hostgroup: k8s_cluster
        init_node_hostgroup: k8s_init_node
        no_lb: true


    - name: Ensure CNI
      hosts: k8s_init_node
      tasks:
        - include_role:
            name: kubernetes.adm.download
            vars_from: helm

        - name: Ensure Cilium repository
          kubernetes.core.helm_repository:
            name: cilium
            repo_url: https://helm.cilium.io/

        - name: Deploy Cilium CNI
          kubernetes.core.helm:
            name: cilium
            chart_ref: cilium/cilium
            release_namespace: kube-system
            chart_version: "{{ cilium_version }}"
            values:
              hostPort:
                enabled: true
              hostServices:
                enabled: true
              containerRuntime:
                integration: crio
              hostFirewall:
                enabled: false
              hubble:
                relay:
                  enabled: true
                ui:
                  enabled: true
              ipam:
                mode: "kubernetes"
              cgroup:
                autoMount:
                  enabled: false
                hostRoot: /sys/fs/cgroup
              kubeProxyReplacement: "strict"
              k8sServiceHost: "{{ control_plane_endpoint.split(':')[0] }}"
              k8sServicePort: "{{ control_plane_endpoint.split(':')[1] }}"

        - name: Patch SELinux context for Hubble relay
          kubernetes.core.k8s_json_patch:
            kind: Deployment
            namespace: kube-system
            name: hubble-relay
            patch:
              - op: replace
                path: /spec/template/spec/securityContext
                value:
                  seLinuxOptions:
                    type: spc_t


    - name: CRI-O CNI Fix https://github.com/cri-o/cri-o/issues/4276
      hosts: k8s_cluster
      tasks:
        - name: Wait for CNI configuration https://github.com/cri-o/cri-o/issues/4276
          wait_for:
            timeout: 120
            path: /etc/cni/net.d/05-cilium.conf
          when: k8s_new_joiner | default(false)

        - name: restart cri-o after changes in /etc/cni/net.d/
          systemd: name=cri-o state=restarted
          become: true
          when: k8s_new_joiner | default(false)


