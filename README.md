install-docker-nginx
====================

Installs nginx as docker systemd service.

System requirements
-------------------

* Ubuntu 16.04
* Docker

Role requirements
-----------------

* python-docker

Tasks
-----

* Create volume paths for docker container
* Create configs via templates
* Setup systemd unit file
* Start/Restart/Reload service

Role parameters
--------------

TODO

Example Playbook
----------------

Usage (without parameters):

    - hosts: servers
      roles:
      - install-docker-nginx

Usage (with parameters):

    - hosts: servers
      roles:
      - role: install-docker-nginx
    configs:
      gitlab:
        https: false
        upstreams:
          gitlab: "172.17.0.1:10080"
        server_name: git.flandigt.de
        locations:
        - location: /
          proxy_to: http://gitlab/
      harbor_ui:
        https: false
        upstreams:
          harbor_ui: "172.17.0.1:50080"
          harbor_registry: "172.17.0.1:55000"
        server_name: harbor.flandigt.de
        locations:
        - location: /
          proxy_to: http://harbor_ui/
        - location: /v1/
          returns: 404
        - location: /v2/
          proxy_to: http://harbor_registry/v2/
        - location: /service/
          proxy_to: http://harbor_ui/service/
        - location: /service/notifications
          returns: 404
