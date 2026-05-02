# Deploying Trino over a Hadoop Cluster on AWS Academy

This repository contains a guided procedure for manually deploying Trino on top of a Hadoop cluster for teaching purposes inside AWS Academy. The idea is that students configure each component step by step, understanding the role of the Hive Metastore, PostgreSQL, and Trino's query engine instead of delegating the process to automation scripts.

## Repository Structure

- `config/hive/`: Hive Metastore configuration files
- `config/trino/`: Trino configuration files, including node properties, JVM settings, and catalog connectors
- `scripts/hive-env.sh`: shell snippet for loading Java 21 and Hive paths in the current session
- `scripts/trino-env.sh`: shell snippet for loading Java 25 and Trino paths in the current session

## Preparing the system

### Updating the OS

Update the OS to ensure all packages are up to date and secure with:

```bash
sudo apt update
sudo apt upgrade -y
```

### Make this repository available on the master server

This repository contains configuration files and scripts that will be used to deploy Trino on top of the Hadoop cluster. To make it available on the master server, clone it and move it to the `/opt` directory with the following commands:

```bash
git clone https://github.com/ptoledo-teaching/dataengineering-trino.git
mkdir -p /opt
sudo mv dataengineering-trino /opt/dataengineering-trino
```

We can add a shortcut for the `hive-env.sh` script to set the necessary environment variables for the Hive Metastore, and `trino-env.sh` for Trino itself:

```bash
ln -s /opt/dataengineering-trino/scripts/hive-env.sh ~/hive-env.sh
ln -s /opt/dataengineering-trino/scripts/trino-env.sh ~/trino-env.sh
```

### Installing necessary packages

Trino will require some additional packages to run properly, such as `net-tools` for network management, Java 21 for the Hive Metastore, PostgreSQL for the Hive Metastore database and Java 25 for Trino itself.

```bash
sudo apt install net-tools openjdk-21-jdk openjdk-25-jdk postgresql -y
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
cp /opt/dataengineering-trino/config/hive/hive-site.xml /opt/hive/conf/
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
source ~/hive-env.sh
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

Once you validate that the Hive Metastore is running, you can stop it (remember that the env should be initialized for hive) with:

```bash
/opt/hive/bin/stop-metastore
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

This will block the terminal you are using. There are ways to prevent this but are not relevant to implement as this is not a production system.

Now we can start Trino in a new terminal (after sourcing the trino environment) with the following command:

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

We can pass sql scripts directly with:

```bash
trino --server localhost:8080 --file myquery.sql
```

Or we can use trino directly by console:

```bash
trino --server localhost:8080
```

Finally, to end trino we run:

```bash
/opt/trino/bin/launcher stop
```

And the we can stop the metastore.

## Final notes

### Shut Down Trino and the Hive Metastore

To stop Trino from the Master:

```bash
/opt/trino/bin/launcher stop
```

To stop the Hive Metastore, find and terminate its process:

```bash
/opt/hive/bin/stop-metastore
```

### About the AWS Academy Session

Each time the AWS Academy session it starts, it starts a timer of 4 hours. When the timer ends, all the resources are stopped automatically. You can check the remaining time in the AWS Academy Canvas Website. If you need more time, you can click on **Start Lab** again to reset the timer. If the time has already passed, you will need to click on **Start Lab** to start a new session.

When a AWS Academy Session starts, it automatically starts all the EC2 machines, in the same way, when the session ends, it stops all the EC2 machines preventing the usage of resources when they are not needed.
