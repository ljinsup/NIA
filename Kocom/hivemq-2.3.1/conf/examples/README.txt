Enable HiveMQ Clustering
========================

1. Open the configurations.properties file in the conf folder with your preferred editor
2. Set the property *cluster.enabled* to true.
3. Open the folder conf/examples
4. Decide which type of cluster you want to use: UDP, TCP, S3 (Best for Amazon AWS)
5. Copy all the xml files from within the folder of your choice (udp, tcp, aws) into the conf folder
6. Do the same for the other HiveMQ nodes.
7. Start each HiveMQ node.

If you have any trouble, please contact support@hivemq.com for assistance.

Specifics for each Cluster Type
================================

TCP
---
* Enter the IP addresses of the cluster instances into all cluster files on all nodes

    For example:
    Replace:
        <TCPPING initial_hosts="localhost[7800]" port_range="0"/>
    with
        <TCPPING initial_hosts="192.168.1.26[7800],192.168.1.27[7800]" port_range="0"/>


UDP
---

* Make sure UDP multicast is enable for your operating system and firewall
* (optional) Customize the UDP multicast port in each cluster xml file


AWS
---

* Create a S3 bucket on AWS first
* Enter your S3 bucket name and your AWS credentials for the S3 Ping in each xml file:

    <S3_PING
        location="ENTER LOCATION"
        access_key="ENTER ACCESS KEY"
        secret_access_key="ENTER SECRET ACCESS KEY"/>