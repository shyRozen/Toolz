date +%T;oc get pods -A | grep test | awk {'print $1," ", $2'} | xargs -l bash -c 'oc delete pod $1 -n $0'
date +%T;oc get pvc -A | grep test | awk {'print $1," ", $2'} | xargs -l bash -c 'oc delete pvc $1 -n $0'
date +%T;oc get volumesnapshot -A | grep test | awk {'print $1," ", $2'} | xargs bash -c 'oc delete volumesnapshot $1 -n $0'
date +%T;oc get pv -A | grep -vi name | awk {'print $1'} | xargs oc delete pv

date +%T;oc get logicalvolume -A | grep -vi name | awk {'print $1'} | xargs oc delete logicalvolume
date +%T;oc get namespace | grep test |awk {'print $1'} | xargs oc delete namespace
date +%T;oc get storageclass | grep -vi name | grep test | awk {'print $1'} | xargs oc delete storageclass
date +%T;oc project default
