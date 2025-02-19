#! /bin/sh

celery -A vision.validatornode worker -l INFO -n vision.validatornode -Q vision.validatornode
