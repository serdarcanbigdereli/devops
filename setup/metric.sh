#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -n namespace"
   echo -e "\t-n Description of what is namespace"
   exit 1 # Exit script after printing help
}

while getopts "n:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$namespace" ]  
then
   echo "Please write, $0 -n namespace ";
   helpFunction
fi

kubectl top pods -n $namespace


