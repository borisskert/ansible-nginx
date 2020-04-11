# install-docker-nginx

Installs nginx as docker systemd service.

## System requirements

* Ubuntu 16.04 or 18.04
* Python 3
* Systemd
* Docker

## Role requirements

* python-docker

## Tasks

* Create volume paths for docker container
* Create configs via templates
* Setup systemd unit file
* Start/Restart/Reload service
* Setup systemd service to reload nginx configuration (default name: `nginx.reload.service`)
* Optionally setup systemd service to renew session ticket encryption keys)

## Role parameters

### Main config

| Variable      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| image_name    | text | no         | nginx   | Docker image name     |
| image_version | text | no         | 1.17.9-alpine | Docker image version |
| https_port    | port as number | no | 443         |  |
| http_port     | port as number | no | 80          |  |
| conf_folder   | path as text   | no | /srv/docker/nginx/conf.d |  |
| rules_folder  | path as text   | no | /srv/docker/nginx/rules  |  |
| certs_folder  | path as text   | no | /srv/docker/nginx/certs  |  |
| ssl_folder    | path as text   | no | /srv/docker/nginx/ssl    |  |
| www_folder    | path as text   | no | /srv/docker/nginx/www    |  |
| log_folder                    | path as text | no | /var/log/nginx               |  |
| script_folder                 | path as text | no | /opt/nginx                   |  |
| clear_dh_parameter            | boolean      | no | false                        |  |
| dh_parameter_bits             | integer number | no | 4096                       |  |
| ticketkey_enabled             | boolean        | no | no                         | Defines if the ssl_session_ticket_key is persisted on filesystem and not managed by this nginx instance itself |
| configs                       | site config as embedded object | no | <empty object> |  |

### mainconfig.config

The site config object is structured as map:
 the key represents the config name, the value is an embedded object with following structure:

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| upstreams     | site upstream as embedded object | no | <empty object> | defines upstreams |
| https         | boolean                          | no | false          | defines if this site is accessible secured via https or not |
| server_name   | text                             | yes |               | defines the site server_name                                |
| locations     | array of locations               | no  | <empty array> | defines the site locations                                  |

#### siteconfig.upstream

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| upstream_name | text | yes |  | the unique name of the corresponding upstream |
| upstream_url  | url as text | yes |  |  |

#### siteconfig.location

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| location      | url as text | yes |         | like: /service/       |
| proxy_to      | absolute url as text | no | <empty> | like: http://harbor_ui/service/ |
| returns       |                      | no | <empty> | like: 404                       |
| options       | dictionary (key-value pairs) | no | <empty> | Nginx options to be templated in your location config |

## Example Playbook

Usage (without parameters):

    - hosts: servers
      roles:
      - install-docker-nginx

Usage (with parameters):

    - hosts: servers
      roles:
      - role: install-docker-nginx
        certs_folder: "/mydrive/letsencrypt/config/live"
        ticketkey_enabled: yes
        configs:
          gitlab:
            https: false
            upstreams:
              gitlab: "172.17.0.1:10080"
            server_name: git.flandigt.de
            locations:
            - location: /
              proxy_to: http://gitlab/
              options:
                client_max_body_size: 8192m
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

## Run tests

Requirements:

* Ansible
* Vagrant
* VirtualBox

```shell script
$ cd tests
$ ./test.sh
```
