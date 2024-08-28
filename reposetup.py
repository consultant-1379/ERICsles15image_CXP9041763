import requests
import socket
import os
import sys

def send_request(post_url,artifacts):
	try:
		print("Creating Dynamic Repo of NCM Artifacts")
		session = requests.Session()
		response = session.post(post_url,data=artifacts)
		if(response.status_code == 200):
			return response.text                
		else:
			print(response.status_code)
			return None 
	except requests.exceptions.RequestException as e:
		print(e)
		print("HTTP Request failed!")   
	return None

params={}
repo=""
repolist = []
repotemplate="dir://{}/,rpm-md,installer{},99,false,false"
sles_media = sys.argv[1]
os.system("mkdir sles_media")
os.system("sudo mount -o loop {} sles_media".format(sles_media))
media_mount = os.path.join(os.getcwd(),"sles_media")
count=1
for i in os.listdir(media_mount):
	print(i)
	if "Module-" in i:
		repolist.append(repotemplate.format(os.path.join(media_mount,i),count))
		count = count + 1
with open("target/classes/my.properties") as properties:
	for line in properties:
		key, val = line.partition("=")[::2]
		if "kgb.package.list" == key:
			val = val.replace("\\","").replace("\n","")
			params={"product":"ENM","drop":"latest.Maintrack","addArtifacts":val}
	repo = send_request("https://ci-portal.seli.wh.rnd.internal.ericsson.com/createRepo/",params)
	print(repo)
version = ""
with open("pom.xml") as pom:
    lines = pom.readlines()
    string = "<artifactId>ERICsles15image_CXP9041763</artifactId>"
    for line in lines:
        if string == line.strip():
            index = lines.index(line)
    version = lines[index+1].strip().replace("<version>","").replace("</version>","")
if "SNAPSHOT" in version:
    version = version.split('-')[0]
    snapshot="-SNAPSHOT"
else:
    snapshot=""
os.system("sed -i 's,<version>.*</version>,<version>{}</version>,' config.xml".format(version))
os.system("sed -i 's/bundle_format=.*/bundle_format=\"%N-%M.%m.%p{}\">/' config.xml".format(snapshot))
os.system("/usr/local/bin/kiwi-ng --debug system boxbuild --no-update-check --box-memory=6144 --shared-path=/{}/sles_media --box leap -- --description {} --add-repo={},rpm-dir,ncm,99,true,false --add-repo=dir://{}/sles_media,rpm-md,installer,99,false,false --add-repo=dir://{}/sles_media/Product-SLES/,rpm-md,installer2,99,false,false --target-dir /tmp/imageroot".format(os.getcwd(),os.getcwd(),repo,os.getcwd(),os.getcwd()))
send_request("https://ci-portal.seli.wh.rnd.internal.ericsson.com/deleteRepo/",{"repo":repo})
os.system("sudo umount {}/sles_media".format(os.getcwd()))
