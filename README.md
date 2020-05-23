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
| https_port    | port as number | no | 443         | Your webserver's https listening port |
| http_port     | port as number | no | 80          | Your webserver's http listening port |
| volume        | path as text   | yes | <empty>    | The location your server will store its files |
| conf_folder   | path as text   | no | {{volume}}/conf.d |  |
| rules_folder  | path as text   | no | {{volume}}/rules  |  |
| certs_folder  | path as text   | no | {{volume}}/certs  |  |
| ssl_folder    | path as text   | no | {{volume}}/ssl    |  |
| www_folder    | path as text   | no | {{volume}}/www    |  |
| log_folder    | path as text   | no | /var/log/nginx    |  |
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
| locations     | dictionary of locations          | no  | <empty dictionary> | defines the site locations;                            |

#### siteconfig.upstream

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| upstream_name | text | yes |  | the unique name of the corresponding upstream |
| upstream_url  | url as text | yes |  |  |

#### siteconfig.location

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| key           | url as text | yes |         | example: /service/       |
| values        | key-value pairs | no | <empty> | nginx location options |

## Example Playbook

### Add to `requirements.yml`:

```yaml
- name: install-nginx
  src: https://github.com/borisskert/ansible-nginx.git
  scm: git
```

Minimal playbook:

```yaml
    - hosts: servers
      roles:
      - role: install-nginx
        volume: /srv/nginx
```

Example with parameters:

```yaml
- hosts: servers
  roles:
  - role: install-nginx
    volume: /srv/nginx
    certs_folder: /srv/letsencrypt/config/live
    logs_folder: /var/log/nginx
    https_port: 443
    http_port: 80
    ticketkey_enabled: yes
    dh_parameter_bits: 2048
    configs:
      gitlab:
        servers:
          - listen:
              - '80'
              - '[::]:80'
            server_name: my.myserver.org
            return: 301 https://$server_name$request_uri
          - listen:
              - '443 ssl http2'
              - '[::]:443 ssl http2'
            server_name: my.myserver.org
            ssl_certificate: ./certs/live/{{item.value.server_name}}/fullchain.pem;
            ssl_certificate_key: ./certs/live/{{item.value.server_name}}/privkey.pem;
            ssl_trusted_certificate: ./certs/live/{{item.value.server_name}}/chain.pem;
            include: ./rules/ssl_parameters.conf;
        locations:
          '/':
            proxy_pass: http://apache/
            include: ./rules/proxy_parameters.conf
          '~ /.well-known':
            root: /var/www/html
            allow: all
```

## Testing

Requirements:

* [Vagrant](https://www.vagrantup.com/)
* [VirtualBox](https://www.virtualbox.org/)
* [Ansible](https://docs.ansible.com/)
* [Molecule](https://molecule.readthedocs.io/en/latest/index.html)
* [yamllint](https://yamllint.readthedocs.io/en/stable/#)
* [ansible-lint](https://docs.ansible.com/ansible-lint/)
* [Docker](https://docs.docker.com/)

### Run within docker

```shell script
molecule test
```

### Run within Vagrant

```shell script
 molecule test --scenario-name vagrant --parallel
```

I recommend to use [pyenv](https://github.com/pyenv/pyenv) for local testing.
Within the Github Actions pipeline I use [my own molecule Docker image](https://github.com/borisskert/docker-molecule).

## License

MIT

## Author Information

* [borisskert](https://github.com/borisskert)
