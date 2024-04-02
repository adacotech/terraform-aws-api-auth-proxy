FROM amazonlinux:2

WORKDIR /tmp
#install the dependencies
RUN yum -y install rsync
RUN amazon-linux-extras install -y python3.8 rust1

RUN mkdir /root/output
COPY . /root/output
WORKDIR /root/output

RUN pip3.8 install --upgrade pip
RUN pip3.8 install -r /root/output/requirements.txt -t /root/output
