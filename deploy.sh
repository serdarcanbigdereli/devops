#input parameters
while getopts "y:n:l:h:" opt
do
   case "$opt" in
      y ) yaml="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      l ) label="$OPTARG" ;;
      h ) hpayaml ="$OPTARG" ;;

   esac
done

#control pods 
status=$( kubectl get pods -n $namespace  -l $label | tail -1 |awk '{print $3}')

if  [ "$status" == "Running" ]
then
	echo "Delete Running Pods!!"
	kubectl delete -f $yaml
	echo "Waiting..."
	sleep 2
fi
echo "New Pods Creating ... "
kubectl apply -f $yaml

max_variable=60
#Show logs 
for (( int=1; int<10; int++ ))
do
    statu=$(kubectl logs -n  $namespace  -l $label)
    echo "Time-->" $int
    echo "Status-->" $statu
    sleep 1
done
#Checks if the pod is opened for 120 seconds
for (( variable=1; variable<max_variable; variable++ ))
do
   status=$( kubectl get pods -n $namespace  -l  $label | tail -1 |awk '{print $3}')
    if [ "$status" == "Running" ]
    then
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    variable=max_variable
    else
    kubectl get pods -n $namespace  -l  $label
    echo "Status--> " $status
    sleep 2
    fi
done

    if [ "$status" == "Running" ]
    then
        echo "Status--> " $status
	kubectl apply -f $hpayaml
    else
        timeout 1 watch kubectl get pods -o wide
    fi
