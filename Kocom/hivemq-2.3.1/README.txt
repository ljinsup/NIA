What is HiveMQ ?
=================
HiveMQ is a MQTT broker, specifically for enterprises which find themself in the emerging age of Machine-to-Machine communication (M2M) and the Internet of Things. It was built from the ground up with maximum scalability, easy management and security in mind.
It offers unique features like an Open Source Plugin SDK for deep integration to an existing application- and IT-Infrastructure, native websocket support and clustering.


Requirements
=================

Hardware:
Memory: 512MB
Disk space: at least 100MB free disk space.

Software:
Operation System: Windows or Linux/Unix/BSD/Mac OS X
Java: OpenJDK 1.7 or newer.

Quickstart
=========

Linux/Unix/MacOSX
-----------------
cd <hivemq_install_directory>/bin
chmod 755 run.sh
./run.sh


Windows
--------

Run:
Run the run.bat file by double clicking on it.


Verify
=======
You should be able to connect to your ip on the default MQTT port 1883

Linux/Unix/BSD:
----------------

netstat -an|grep 1883

You should see a line like the following in the output


tcp46      0      0  *.1883                 *.*                    LISTEN



Windows:
---------
Start the CMD and type:


netstat -an|find "1883"


Documentation
========
The full documentation can be found here: www.hivemq.com/docs/hivemq/latest
