mkdir ~/ocdata/4.11/$1
oc adm must-gather --image=quay.io/rhceph-dev/odf4-odf-lvm-must-gather-rhel8:latest-4.11  --dest-dir=/home/srozen/ocdata/4.11/$1/
cd ~/ocdate/4.11/$1
tar -zcvf ../must-gather-thin-util.tar.gz ~/ocdata/4.11/$1; mv ../must-gather-thin-util.tar.gz /home/srozen/ocdata/4.11/$1/


