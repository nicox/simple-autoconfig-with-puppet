#!/bin/bash
apt-get update; apt-get upgrade
apt-get install puppet puppet-module-puppetlabs-stdlib

puppet apply all.pp



