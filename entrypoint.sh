#!/bin/bash
set -e

exec /usr/sbin/asterisk -f -U asterisk -G asterisk -vvv
