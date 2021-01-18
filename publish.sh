#!/bin/bash
set -e

git checkout master
git push
git checkout release
git pull
git rebase master
git push
git checkout master
