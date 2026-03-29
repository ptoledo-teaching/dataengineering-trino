export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

export HADOOP_HOME=/opt/hadoop-3.4.3
export HADOOP_PREFIX=/opt/hadoop-3.4.3
export HADOOP_CONF_DIR=/opt/hadoop-3.4.3/etc/hadoop
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

java -version
hadoop version