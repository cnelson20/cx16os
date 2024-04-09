#!/usr/bin/env bash

sudo umount $1
sudo losetup -d /dev/loop21
