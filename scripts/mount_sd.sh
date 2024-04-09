#!/usr/bin/env bash

sudo losetup -P /dev/loop21 $1
mkdir $2
sudo mount /dev/loop21p1 $2
