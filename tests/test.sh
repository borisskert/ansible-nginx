#!/bin/bash
set -e

vagrant up --provision

ansible-galaxy install -r requirements.yml -p ./roles --force

echo "Waiting for answer on port 22..."
while ! timeout 1 nc -z 192.168.33.26 22; do
  sleep 0.2
done

ansible-playbook -i inventory.ini test.yml

ansible-playbook -i inventory.ini test.yml \
  | grep -q 'changed=0.*failed=0' \
  && (echo 'Idempotence test: pass' && exit 0) \
  || (echo 'Idempotence test: fail' && exit 1)

echo "Waiting for nginx answer ..."
while ! timeout 1 nc -z 192.168.33.26 80; do
  sleep 0.2
done

curl -s http://192.168.33.26:80 \
 | grep -q '</html>' \
  && (echo 'curl test: pass' && exit 0) \
  || (echo 'curl test: fail' && exit 1)

vagrant destroy -f
