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
        http_upstreams:
          gitlab:
            port: 10080
            name: gitlab
            server_name: git.flandigt.de
