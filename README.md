This api takes 3 options:

1. Update vCenter template from S3 bucket:
http://ipaddress:8000/update/[platform]/[version]
where,
[platform] = vcloud or vcenter
[version] = string representing the version, such as 1.5.3

2. Update specific ASAA to the latest version
http://ipaddress:8000/deploy/[platform]/[name]
where,
[platform] = vcloud or vcenter
[name] = string representing the name, such as ASAA_vCenter_Dev6 or ASAA_vCloud_Dev2

3. In development - Retrive status of the job
http://ipaddress:8000/status/[jobid]
where,
[jobid] =  number you should receive when running Option 1 or 2

systemd service file:
/etc/systemd/system/assa_deploy.service
start api service:
systemtcl start assa_deploy.service

stop api service:
systemtcl stop assa_deploy.service

view service log
journalctl -u assa_deploy.service

Application log file:
/opt/api_deploy/LogFile.csv
