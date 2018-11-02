#!/bin/bash

ssh london sudo rm -rf /data/cassandra/*
kubectl delete pod --selector app=ota-cassandra
sleep 20
kubectl delete pod --selector app=ota-crypt-vault
kubectl delete secret --selector 'createdBy=OtaDeployState'
