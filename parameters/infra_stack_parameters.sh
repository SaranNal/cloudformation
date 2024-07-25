#!/bin/bash
# infra_stack_parameters.sh

PublicSubnets="subnet-0bc9e2992de3412ae,subnet-0a2ee0382e3fffdea,subnet-07d88f457c3d22490,subnet-02f6f269c97e21a69,subnet-0b09996022939ca89,subnet-09913ab8e8aa50d3f"
PrivateSubnets="subnet-0bf8512f3dc77c79b,subnet-010780120c4aa74c6,subnet-0a211aafd0e1af03b,subnet-067999a6e63c7abe8,subnet-0b7f741ecc9c96c4e,subnet-0e92d3f901abbe4d2"
INFRA_STACK_PARAMETERS=("ParameterKey=PublicSubnets,ParameterValue=${PublicSubnets}" "ParameterKey=PrivateSubnets,ParameterValue=${PrivateSubnets}")
