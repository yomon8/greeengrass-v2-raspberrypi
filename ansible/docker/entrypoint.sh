#!/bin/bash
eval $(ssh-agent)

exec ansible-playbook "${@}"