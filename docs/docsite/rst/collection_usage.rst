.. _ansible_collections.kubernetes.adm.docsite.collection_usage:

Using The Collection
====================
This document demonstrate one way to structure your Ansible project around the collection. It's by no means the only way.

Common Role
-----------

The common role contains the cluster wide parameters. Those variables are used for a *single* cluster.

Care must be taken when maintaining multiple clusters in the same inventory.

Inventory Structure
-------------------

For every cluster in the inventory create the following groups:

- ``prod_control_plane``: The control plane group.
- ``prod_workers``: The workers group.
- ``prod_cluster``: The cluster group. Contains both ``prod_control_plane`` and ``prod_workers`` groups.
- ``prod_init_node``: The first control plane node. Only used during cluster creation.

Add any unique prefix or suffix to distinguish different clusters(prod in this case).

Use group vars in the ``prod_cluster`` group to specifiy all the common paramaters:

.. code-block:: yaml+jinja

    kubernetes_version: "1.23.0"
    kubeadm_apiversion: v1beta3
    kubeadm_skip_phases: ["addon/kube-proxy"]
    cluster_pod_cidr: 172.16.0.0/16
    cluster_service_cidr: 172.17.0.0/16
    control_plane_endpoint: cluster.xzy:6443
    control_plane_hostgroup: prod_control_plane
    swap_state: disabled
    joined_control_plane_node: node1

The ``control_plane_hostgroup`` should reference the control plane group ``prod_control_plane``.


Cluster Bootstrapping Playbook
------------------------------

Review all the requirements in :ref:`ansible_collections.kubernetes.adm.docsite.requirements`.

Node Requirements
^^^^^^^^^^^^^^^^^
The ``prepare`` role ensures that the nodes have all ther Kubernetes and kubeadm requiremnets statisfied.
Except the following:

- Hostnames.
- Domain name resolution.
- Host firewalls.

For RHEL 8 based distro the following works:

.. code-block:: yaml+jinja

  - name: Ensure hostname and /etc/hosts for nodes and no firewall
    gather_facts: false
    hosts: all
    become: yes
    tasks:
      - name: /etc/hosts
        blockinfile:
          path: /etc/hosts
          block: |
            {% for host in groups['prod_cluster'] %}
            {{hostvars[host].ansible_host }} {{ host }}
            {% endfor %}
            # CLUSTER ENDPOINT
            192.168.33.10 cluster.xzy

      - name: Set hostname
        hostname: name="{{ inventory_hostname }}"

      - name: Ensure firewalld is stopped and disabled
        systemd:
          name: firewalld
          state: stopped
          enabled: false

In the above, we add all the hostnames and IP address of all the cluster nodes to ``/etc/hosts``.
The ``cluster.xzy`` entry is our ``control_plane_endpoint``.


Cluster Creation
^^^^^^^^^^^^^^^^
To create a cluster you can import the ``cluster`` playbook from the collection:

.. code-block:: yaml+jinja

  - import_playbook: kubernetes.adm.cluster
    vars:
      control_plane_hostgroup: prod_control_plane
      workers_hostgroup: prod_workers
      cluster_hostgroup: prod_cluster
      init_node_hostgroup: prod_init_node
