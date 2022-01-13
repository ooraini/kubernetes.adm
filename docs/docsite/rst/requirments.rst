.. _ansible_collections.kubernetes.adm.docsite.requirements:

Requirements
============

Ansible Controller
^^^^^^^^^^^^^^^^^^

To install the collection, add the following to your ``requirements.yml`` file:

.. code-block:: yaml+jinja

    collections:
      - name: https://github.com/ooraini/kubernetes.adm
        type: git

You will need ``jmespath`` from `PyPi <https://pypi.org/project/jmespath/>`_:

.. code-block:: bash

    pip3 install jmespath --user # Skip --user if you are using venv

Kubernetes Entry
^^^^^^^^^^^^^^^^

When you perform any *control* level operation your Ansible target host will need to access the API server and have
some dependencies installed. In particular `kubernetes.core <https://github.com/ansible-collections/kubernetes.core>`_
dependencies:

.. code-block::

    PyYAML
    jsonpatch
    kubernetes

By default, they will be installed on all the control plane nodes by the ``prepare`` role.
