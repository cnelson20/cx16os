#!/usr/bin/env bash

sudo losetup -P /dev/loop21 $1
mkdir mnt/
sudo mount /dev/loop21p1 mnt/
