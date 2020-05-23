# install-docker-nginx

Installs nginx as docker systemd service.

## Supported operating systems

* Ubuntu 16.04
* Ubuntu 18.04
* Ubuntu 20.04
* Debian 9
* Debian 10

## System requirements

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
| upstreams                     | dictionary of `upstream` | no | <empty object>   | Defines all nginx upstreams |
| configs                       | dictionary of `site`     | no | <empty object>   | Defines all nginx sites |
| rules                         | dictionary of `rule`     | no | <empty object>   | Defines all reusable nginx rules |

### Definition of `site`

The site config object is structured as map:
 the key represents the config name, the value is an embedded object with following structure:

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| servers       | dictionary of `server` | no | <empty object> | Defines the server configs for this `site` |

### Definition of `upstream`

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| key           | text | yes |  | The upstream name |
| value         | text | yes |  | The upstream value |

### Definition of `server`

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| options       | multi-value dictionary of values | yes |         | Defines the options for this `server`       |
| locations     | dictionary of `location`         | no  | <empty> | Defines the locations for this `server` |

### Definition of `location`

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| key           | url  | yes |                | The location as url   |
| values        | dictionary | no   | <empty> | The options for this `location` |

### Definition of `rule`

| Property      | Type | Mandatory? | Default | Description           |
|---------------|------|------------|---------|-----------------------|
| key           | text | yes        |         | The name of the rules file |
| values        | multi-value dictionary of values | yes | | The nginx rules |

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
    upstreams:
      apache: 172.17.0.1:8080
      gitlab: 172.17.0.1:10081
    rules:
      ssl:
        ssl_protocols: TLSv1.3 TLSv1.2
        ssl_ciphers: "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:\
          EECDH+ECDSA+SHA512:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:\
          ECDH+AESGCM:ECDH+AES256:DH+AESGCM:DH+AES256:RSA+AESGCM:\
          !aNULL:!eNULL:!LOW:!RC4:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS"
        ssl_prefer_server_ciphers: 'on'
        ssl_dhparam: ./ssl/{{ dh_parameter_filename }}
        ssl_ecdh_curve: secp384r1
        add_header: "Strict-Transport-Security 'max-age=31536000; \
          includeSubDomains; preload' always"
        ssl_stapling: 'on'
        ssl_stapling_verify: 'on'
        ssl_session_cache: shared:TLS:2m
        ssl_buffer_size: 4k
        ssl_session_timeout: 10m
        ssl_session_tickets: 'on'
        ssl_session_ticket_key: ./ssl/{{ ticketkey_filename }}
      proxy:
        proxy_set_header:
          - Host $http_host
          - X-Real-IP $remote_addr
          - X-Forwarded-For $proxy_add_x_forwarded_for
          - X-Forwarded-Proto $scheme
        proxy_cookie_path: '/ "/; secure"'
        proxy_buffering: 'off'
        proxy_request_buffering: 'off'
    configs:
      apache:
        servers:
          - options:
              listen:
                - '80'
                - '[::]:80'
            server_name: my.http.server
            locations:
              '/':
                proxy_pass: http://apache/
                include: ./rules/proxy.conf
              '~ /.well-known':
                root: /var/www/html
                allow: all
      gitlab:
        servers:
          - options:
              listen:
                - '80'
                - '[::]:80'
            server_name: my.gitlab.server
            return: 301 https://$server_name$request_uri
          - options:
              listen:
                - '443 ssl http2'
                - '[::]:443 ssl http2'
              server_name: my.gitlab.server
              ssl_certificate: ./certs/live/my.gitlab.server/fullchain.pem
              ssl_certificate_key: ./certs/live/my.gitlab.server/privkey.pem
              ssl_trusted_certificate: ./certs/live/my.gitlab.server/chain.pem
              include: ./rules/ssl.conf
            locations:
              '/':
                proxy_pass: http://gitlab/
                include: ./rules/proxy.conf
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
