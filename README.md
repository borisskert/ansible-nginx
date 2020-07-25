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
| nginx_image_name    | text | no         | nginx   | Docker image name     |
| nginx_image_version | text | no         | 1.17.9-alpine | Docker image version |
| nginx_https_port    | port as number | no | 443         | Your webserver's https listening port |
| nginx_http_port     | port as number | no | 80          | Your webserver's http listening port |
| nginx_volume        | path as text   | yes | <empty>    | The location your server will store its files |
| nginx_conf_folder   | path as text   | no | {{nginx_volume}}/conf.d |  |
| nginx_rules_folder  | path as text   | no | {{nginx_volume}}/rules  |  |
| nginx_certs_folder  | path as text   | no | {{nginx_volume}}/certs  |  |
| nginx_ssl_folder    | path as text   | no | {{nginx_volume}}/ssl    |  |
| nginx_www_folder    | path as text   | no | {{nginx_volume}}/www    |  |
| nginx_log_folder    | path as text   | no | /var/log/nginx    |  |
| nginx_script_folder                 | path as text | no | /opt/nginx                   |  |
| nginx_clear_dh_parameter            | boolean      | no | false                        |  |
| nginx_dh_parameter_bits             | integer number | no | 4096                       |  |
| nginx_ticketkey_enabled             | boolean        | no | no                         | Defines if the ssl_session_ticket_key is persisted on filesystem and not managed by this nginx instance itself |
| nginx_config                        | `nginx_config` object | no | <empty object>      | Specifies the main nginx.conf |
| nginx_configs                       | dictionary of `nginx_config` objects | no | <empty object>   | Defines all config files in `conf.d` directory |
| nginx_rules                         | dictionary of `nginx_config` objects | no | <empty object>   | Defines all rule files in `rules` directory |

### Definition of `nginx_config`

The site config object is structured as map of key value pairs. Values may be simple strings, lists and embedded objects.
Embedded objects also may contain the same structure as `nginx_config` objects.

#### Templating rules

##### Simple string property
```yaml
my_config:
  my_key: my_value
```
is templated to:
```
my_key my_value;
```

##### List property
```yaml
my_config:
  my_key:
    - my_value_one
    - my_value_two
    - my_value_three
```
is templated to:
```
my_key my_value_one;
my_key my_value_two;
my_key my_value_three;
```

##### Embedded object property
```yaml
my_config:
  my_obj:
    my_key_one: my_value_one
    my_key_two: my_value_two
```
is templated to:
```
my_obj {
  my_key_one my_value_one;
  my_key_two my_value_two;
}
```

## Example Playbook

### Add to `requirements.yml`:

```yaml
- name: install-nginx
  src: https://github.com/borisskert/ansible-nginx.git
  scm: git
```

### Example `playbook.yml`:

```yaml
- hosts: servers
  roles:
  - role: install-nginx
    nginx_image_version: 1.17.10-alpine
    nginx_volume: /srv/nginx
    nginx_http_port: 8080
    nginx_https_port: 8443
    nginx_clear_dh_parameter: false
    nginx_dh_parameter_bits: 1024
    nginx_ticketkey_enabled: true
    nginx_config:
      user: nginx
      worker_processes: auto
      error_log: /var/log/nginx/error.log warn
      pid: /var/run/nginx.pid
      events:
        worker_connections: '1024'
      http:
        include:
          - /etc/nginx/mime.types
          - /etc/nginx/conf.d/*.conf
        default_type: application/octet-stream
        log_format: |-
          main  '$remote_addr - $remote_user [$time_local] "$request" '
          '$status $body_bytes_sent "$http_referer" '
          '"$http_user_agent" "$http_x_forwarded_for"'
        access_log: /var/log/nginx/access.log  main
        sendfile: 'on'
        keepalive_timeout: '65'
    nginx_rules:
      ssl:
        ssl_protocols: TLSv1.3 TLSv1.2
        ssl_ciphers: "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:\
          EECDH+ECDSA+SHA512:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:\
          ECDH+AESGCM:ECDH+AES256:DH+AESGCM:DH+AES256:RSA+AESGCM:\
          !aNULL:!eNULL:!LOW:!RC4:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS"
        ssl_prefer_server_ciphers: 'on'
        ssl_dhparam: ./ssl/{{ nginx_dh_parameter_filename }}
        ssl_ecdh_curve: secp384r1
        add_header: "Strict-Transport-Security 'max-age=31536000; \
          includeSubDomains; preload' always"
        ssl_stapling: 'on'
        ssl_stapling_verify: 'on'
        ssl_session_cache: shared:TLS:2m
        ssl_buffer_size: 4k
        ssl_session_timeout: 10m
        ssl_session_tickets: 'on'
        ssl_session_ticket_key: ./ssl/{{ nginx_ticketkey_filename }}
      proxy:
        proxy_set_header:
          - Host $http_host
          - X-Real-IP $remote_addr
          - X-Forwarded-For $proxy_add_x_forwarded_for
          - X-Forwarded-Proto $scheme
        proxy_cookie_path: '/ "/; secure"'
        proxy_buffering: 'off'
        proxy_request_buffering: 'off'
    nginx_configs:
      upstreams:
        upstream apache:
          server: 172.17.0.1:10080
        upstream gitlab:
          server: 172.17.0.1:10081
      apache:
        server:
          - listen:
              - '80'
              - '[::]:80'
            server_name: my.http.server
            location /:
              proxy_pass: http://apache/
              include: ./rules/proxy.conf
            location ~ /.well-known:
              root: /var/www/html
              allow: all
          - listen:
              - '443 ssl http2'
              - '[::]:443 ssl http2'
            server_name: my.http.server
            ssl_certificate: certs/live/my.https.server/fullchain.pem
            ssl_certificate_key: certs/live/my.https.server/privkey.pem
            ssl_trusted_certificate: certs/live/my.https.server/chain.pem
            include: ./rules/ssl.conf
            location /:
              proxy_pass: http://apache
              include: ./rules/proxy.conf
            location ~ /.well-known:
              root: /var/www/html
              allow: all
      gitlab:
        server:
          - listen:
              - '80'
              - '[::]:80'
            server_name: my.gitlab.server
            return: 301 https://$server_name$request_uri
          - listen:
              - '443 ssl http2'
              - '[::]:443 ssl http2'
            server_name: my.gitlab.server
            ssl_certificate: certs/live/my.gitlab.server/fullchain.pem
            ssl_certificate_key: certs/live/my.gitlab.server/privkey.pem
            ssl_trusted_certificate: certs/live/my.gitlab.server/chain.pem
            include: ./rules/ssl.conf
            location /:
              proxy_pass: http://gitlab/
              include: ./rules/proxy.conf
            location ~ /.well-known:
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
