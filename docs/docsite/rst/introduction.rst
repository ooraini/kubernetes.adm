.. _ansible_collections.kubernetes.adm.docsite.introduction:

Introduction
============
This collection helps you deploy ``kubeadm`` based Kubernetes clusters. It's a wrapper around ``kubeadm``.

The collection has roles that correspond to ``kubeadm`` commands. 
For example the ``init`` role corresponds to the ``kubeadm init`` command.

The collection uses the CRI-O container runtime(CR). Support for other CRs is not planned.

The collection is designed and tested for RHEL(>= 8) based distributions. Support for other distributions is not planned.

Providing extension points to support different CRs or distributions is a goal.
The collection uses *tasks_file* variable for this purpose. The following should demonstrate.
In the ``prepare`` role there is the variable ``cri_tasks: _crio.yml``. The ``_crio.yml`` file is a *tasks* file which
installs CRI-O. To plug in an alternative CR, set the value of ``cri_tasks`` to your *own* tasks file that installs your favorite CR.

Kubeadm
-------
The collection is *just* a wrapper around ``kubeadm``. It's not an abstraction on top of it. Therefore, it's
necessary to understand ``kubeadm`` to be able to use the collection.



Roles
-----
The collection includes the following roles:

- common: Contains common parameters for the cluster.
- prepare: Prepare the node for Kubernetes installation.
- init: Initializes a new cluster using ``kubeadm init``
- pre_join: Generate a bootstrap token and uploads the encrypted certificates.
- join: Join a new node to an existing cluster.
- upgrade: Upgrade Kubernetes control plane and workers.
- keepalived: Setup a HA floating IP using ``keepalived``.
- api_server_lb: Setup a load balancer for the API server using HAProxy and keepalived for HA cluster.
- download: Download arbitrary files, mostly for installing CLIs from Github releases.

Bootstrapping a Cluster
-----------------------

To create a cluster using ``kubeadm`` you run the following commands:

- ``kubeadm init``: On the first control plane node.
- ``kubeadm join --control-plane``: On the reset of the control plane nodes.
- ``kubeadm join``: On the reset of the worker nodes.

For the collection, in addition to the ``init`` and ``join`` roles, you will need the ``prepare`` and ``pre_join`` roles:

.. code-block:: yaml+jinja

    - name: Prepare nodes for Kubernetes
      hosts: "{{ cluster_hostgroup }}"
      any_errors_fatal: true
      roles: [ kubernetes.adm.prepare ]


    - name: Setup Load balancer for Kubernetes API server
      hosts: "{{ control_plane_hostgroup }}"
      any_errors_fatal: true
      roles:
        - role: kubernetes.adm.api_server_lb
          when: (no_lb | default(false)) == false
        

    - name: Init first control plane node
      hosts: "{{ init_node_hostgroup }}"
      any_errors_fatal: true
      roles: [kubernetes.adm.init]


    - hosts: "{{ init_node_hostgroup }}"
      any_errors_fatal: true
      roles: [kubernetes.adm.pre_join]


    - name: Join the rest of the control plane nodes
      hosts: "{{ control_plane_hostgroup }},!{{ init_node_hostgroup }}"
      any_errors_fatal: true
      serial: 1
      roles: [kubernetes.adm.join]


    - name: Join worker nodes
      hosts: "{{ workers_hostgroup }}"
      roles: [kubernetes.adm.join]
      strategy: free

Playbook explanation:

- Run the prepare role on all nodes. Stop on any failure.
- Run the api_server_lb role on the control plane nodes to setup a highly available load balancer. Stop on any failure.
- Run the init role on the first control plane node. Stop on any failure.
- Run the pre_join role to set the required facts to join new nodes later. Stop on any failure.
- Run the join role on the reset of the control plane nodes. One by one. Stop on any failure.
- Run the join role on the worker nodes.

Cluster Upgrade
---------------


As mentioned before, the collection as a wrapper around kubeadm. We don't attempt to hide kubeadm and its interface.
So, before upgrading the cluster, follow the kubeadm documentation.
Follow any guidelines and recommendations that are necessary.
Perform any required manual migration for any configuration or resource configs.

The kubeadm upgrade process is the following:

- Upgrade the first(any one will work)  control plane node.
- Upgrade the reset of the control plane nodes
- Upgrade the kubelet on the control plane nodes.
- Upgrade the worker nodes and then their kubelets.

The following playbook demonstrates:

.. code-block:: yaml+jinja

  - hosts: "{{ init_node_hostgroup }}"
    any_errors_fatal: true
    roles: [{ role: kubernetes.adm.upgrade, phase: facts }]

  - hosts: "{{ init_node_hostgroup }}"
    any_errors_fatal: true
    roles: [{ role: kubernetes.adm.upgrade, phase: apply }]

  - hosts: "{{ control_plane_hostgroup }},!{{ init_node_hostgroup }}"
    serial: 1
    any_errors_fatal: true
    roles: [{ role: kubernetes.adm.upgrade, phase: node }]

  - hosts: "{{ control_plane_hostgroup }}"
    serial: 1
    any_errors_fatal: true
    roles: [{ role: kubernetes.adm.upgrade, phase: kubelet }]

  - hosts: "{{ workers_hostgroup }}"
    serial: 10%
    max_fail_percentage: 20
    roles: 
      - { role: kubernetes.adm.upgrade, phase: node }
      - { role: kubernetes.adm.upgrade, phase: kubelet }
