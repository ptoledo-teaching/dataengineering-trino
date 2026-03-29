# Deploying Trino over a Hadoop Cluster on AWS Academy

## Preparing the system

### Make this repository available on the master server

This repository contains configuration files and scripts that will be used to deploy Trino on top of the Hadoop cluster. To make it available on the master server, clone it and move it to the `/opt` directory with the following commands:

```bash
git clone https://github.com/ptoledo-teaching/dataengineering-trino.git
mkdir -p /opt
sudo mv dataengineering-trino /opt/dataengineering-trino
```

### Updating the OS

Update the OS to ensure all packages are up to date and secure with:

```bash
sudo apt update
sudo apt upgrade -y
```

### Installing necessary packages

Trino will require some additional packages to run properly, such as `net-tools` for network management, Java 21 for the Hive Metastore, PostgreSQL for the Hive Metastore database and Java 25 for Trino itself.

```bash
sudo apt install net-tools openjdk-21-jdk openjdk-25-jdk postgresql  -y
```

## Configuring Trino

### Configuring PostgreSQL for Hive Metastore

PostgreSQL will be used as the backend database for the Hive Metastore. We need to create a database and set a password for the `postgres` user:

```bash
sudo -u postgres createdb metastore
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'password';"
```

### Install Hive Metastore

The Hive Metastore is a critical component for Trino to interact with the Hadoop ecosystem. We will install the standalone Hive Metastore and configure it to use PostgreSQL as its backend.

```bash
cd /tmp
wget https://downloads.apache.org/hive/hive-standalone-metastore-4.2.0/hive-standalone-metastore-4.2.0-bin.tar.gz
tar -xzf hive-standalone-metastore-4.2.0-bin.tar.gz
sudo mv apache-hive-metastore-4.2.0-bin /opt/hive
cp ~/dataengineering-trino/config/hive/hive-site.xml /opt/hive/conf/
```

We can add a shortcut for the `hive-env.sh` script to set the necessary environment variables for the Hive Metastore, and `trino-env.sh` for Trino itself:

```bash
ln -s /opt/dataengineering-trino/scripts/hive-env.sh ~/hive-env.sh
ln -s /opt/dataengineering-trino/config/trino/env.sh ~/trino-env.sh
```

### Adding PostgreSQL JDBC driver to Hive Metastore

For Hive Metastore to connect to PostgreSQL, we need to add the PostgreSQL JDBC driver to its classpath. We can do this by downloading the driver and placing it in the Hive lib directory:

```bash
cd /opt/hive/lib
wget https://jdbc.postgresql.org/download/postgresql-42.7.10.jar
```

### Initialize Hive Metastore schema in PostgreSQL

First we need to create the necessary directory in HDFS for the Hive Metastore to store its data:

```bash
source ~/hadoop-env.sh
start-dfs.sh
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod 1777 /user/hive/warehouse
stop-dfs.sh
```

Then we can initialize the Hive Metastore schema in PostgreSQL:

```bash
source /opt/dataengineering-trino/scripts/hive-env.sh
/opt/hive/bin/schematool -dbType postgres -initSchema
```

In a new terminal, then we can start the Hive Metastore service after running the source command to set the environment variables for hive metastore:

```bash
source ~/hive-env.sh
/opt/hive/bin/start-metastore
```

Finally, we can check that the Hive Metastore is running and listening on the correct port (9083):

```bash
netstat -tulnp | grep 9083
```

## Installing Trino

### Download and unpack Trino

We need to start by downloading the latest version of Trino and unpacking it in the `/opt` directory:

```bash
cd /tmp
wget https://github.com/trinodb/trino/releases/download/480/trino-server-480.tar.gz
tar -xzf trino-server-480.tar.gz
sudo mv trino-server-480 /opt/trino
wget https://github.com/trinodb/trino/releases/download/480/trino-cli-480 -O trino
chmod +x trino
sudo mv trino /usr/local/bin/
```

We need to create the `etc` directories for Trino's configuration files and move the provided configuration files there:

```bash
MASTER_IP=$(hostname -I | awk '{print $1}')
mkdir -p /opt/trino/data
mkdir -p /opt/trino/etc
cp /opt/dataengineering-trino/config/trino/node.properties /opt/trino/etc/
cp /opt/dataengineering-trino/config/trino/jvm.config /opt/trino/etc/
cp /opt/dataengineering-trino/config/trino/config.master.properties /opt/trino/etc/config.properties
sed -i "s/{master_ip_private}/$MASTER_IP/g" /opt/trino/etc/config.properties
cp /opt/dataengineering-trino/config/trino/env.sh /opt/trino/etc/
chmod +x /opt/trino/etc/env.sh
mkdir -p /opt/trino/etc/catalog
cp /opt/dataengineering-trino/config/trino/hive.properties /opt/trino/etc/catalog
sed -i "s/{master_ip_private}/$MASTER_IP/g" /opt/trino/etc/catalog/hive.properties
mkdir -p /opt/trino/hadoop-conf
cp /opt/hadoop-3.4.3/etc/hadoop/core-site.xml /opt/trino/hadoop-conf/
cp /opt/hadoop-3.4.3/etc/hadoop/hdfs-site.xml /opt/trino/hadoop-conf/
```

### Starting Trino

Trino requires the Hive Metastore to be running before it can start, so make sure to start the Hive Metastore service first with:

```bash
source ~/hive-env.sh
/opt/hive/bin/start-metastore
```

Now we can start Trino with the following command:

```bash
/opt/trino/bin/launcher start
```

And we can check trino status with:

```bash
/opt/trino/bin/launcher status
```

After starting Trino, we can connect to it using the Trino CLI and run a simple query to verify that it's working properly:

```bash
trino --server localhost:8080 --execute "SELECT * FROM hive.information_schema.tables"
```

To stop Trino and the Hive Metastore, you must terminate the Trino process with:

```bash
/opt/trino/bin/launcher stop
```

Then you can stop the Hive Metastore by terminating its process.