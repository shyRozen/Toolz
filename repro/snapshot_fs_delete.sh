project="storage-test1"
origin_pvc="pvc-test-origin"
origin_pod="pod-test-origin"
oc new-project $project

oc create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $origin_pvc
  namespace: $project
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 300Gi
  storageClassName: odf-lvm-vg1
  volumeMode: Filesystem
---
apiVersion: v1
kind: Pod
metadata:
  name: $origin_pod
  namespace: $project
spec:
  containers:
  - image: quay.io/ocsci/nginx:latest
    name: web-server
    volumeMounts:
    - mountPath: /var/lib/www/html
      name: mypvc
  volumes:
  - name: mypvc
    persistentVolumeClaim:
      claimName: $origin_pvc
      readOnly: false

EOF
start=$(date +%s)
while true
do
status=`oc get pods $origin_pod -n $project | grep -vi name`
end=$(date +%s)
elapsed=$(($end-$start))
echo $status+" "+$elapsed+" sec since check start "+$start
if [[ $status == *"Running"* ]]
then
  break
fi
if [ $elapsed -ge 120 ]
then
  echo "Waited 5 minutes and pod is not running "
  exit
fi
done
oc rsh $origin_pod apt-get update
oc rsh $origin_pod apt-get install -y fio
oc rsh $origin_pod fio --name=fio-rand-readwrite --filename=/var/lib/www/html/fio.txt --readwrite=write --bs=100M --direct=1 --numjobs=1 --size=30g --iodepth=4 --invalidate=0 --fsync_on_close=1 --rwmixread=50 --ioengine=libaio --rate=1500m --buffer_pattern=0xdeadface --output-format=json

for i in {1..14}
do
  # if [ i -eq 1 ]
  # then
oc create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: restored-snp-test$i
  namespace: $project
spec:
  source:
    persistentVolumeClaimName: $origin_pvc
  volumeSnapshotClassName: odf-lvm-vg1
EOF
# else
#   minusi=$i-1
#   oc create -f - <<EOF
# apiVersion: snapshot.storage.k8s.io/v1
# kind: VolumeSnapshot
# metadata:
#   name: restored-snp-test$i
#   namespace: $project
# spec:
#   source:
#     persistentVolumeClaimName: restored-pvc-snp-test$minusi
#   volumeSnapshotClassName: odf-lvm-vg1
# EOF
# fi
sleep 10
oc create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc-snp-test$i
  namespace: $project
spec:
  accessModes:
  - ReadWriteOnce
  dataSource:
    apiGroup: snapshot.storage.k8s.io
    kind: VolumeSnapshot
    name: restored-snp-test$i
  resources:
    requests:
      storage: '322122547200'
  storageClassName: odf-lvm-vg1
  volumeMode: Filesystem
---
EOF
sleep 10
oc create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-restored-test-$i
  namespace: $project
spec:
  containers:
  - image: quay.io/ocsci/nginx:latest
    name: web-server
    volumeMounts:
    - mountPath: /var/lib/www/html
      name: mypvc
  volumes:
  - name: mypvc
    persistentVolumeClaim:
      claimName: restored-pvc-snp-test$i
      readOnly: false
EOF
start=$(date +%s)
while true
do
status=`oc get pods pod-restored-test-$i -n $project | grep -vi name`
end=$(date +%s)
elapsed=$(($end-$start))
echo $status+" "+$elapsed+" sec since check start "+$start
if [[ $status == *"Running"* ]]
then
  break
fi
if [ $elapsed -ge 120 ]
then
  echo "Waited 5 minutes and pod is not running "
  exit
fi
done
sleep 10
oc delete VolumeSnapshot restored-snp-test$i
done
oc delete pod $origin_pod
oc delete pvc $origin_pvc
# outcome
# even after deletion of origin pvc utility is not updated as pvc is autonomous

  # LV                                   VG  Attr       LSize    Pool        Origin Data%  Meta%  Move Log Cpy%Sync Convert
  # 174139da-edc0-4d93-b8a7-f811ec39bfc6 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 1fd6997a-10bb-4245-849e-6ebe01dd16fd vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 257328ec-1231-4a31-9db6-b55357757292 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 3d160f68-cbe4-459b-90f8-ae89b0d9365c vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 3f58d8b0-7d0b-4f17-9538-41b8cc6e26d4 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 4c4d1a28-74dc-47c1-964d-833253361969 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # 605b4c82-2e82-4aa2-a32c-e399b81d7e2a vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # b864fd3a-3fa2-41f8-a90f-b3a897ce4970 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # bc59d617-a15d-4ed6-9479-bf27ad2f9c1e vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # bf987a7a-36a7-43f8-bdb8-49efc61ce2c1 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # db3f1f94-0a0f-49b8-baa4-55ef44639eae vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # e2503638-c2e4-49fa-98f3-d1fe2622d2cc vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # f2a25e58-b0bd-43aa-ac0b-3839608f3eaa vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # fc2c5d07-51d7-4e0a-84f0-a2369e9b1269 vg1 Vwi-aotz-k  300.00g thin-pool-1        10.05
  # thin-pool-1                          vg1 twi-aotz-- <674.81g                    4.47   12.31
