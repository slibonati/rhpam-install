#!/bin/bash
INSTALL_DIR=/opt
JBOSS_HOME=$INSTALL_DIR/jboss-eap-7.3

if [[ -d "$JBOSS_HOME" ]]
then
    rm -rf $JBOSS_HOME
fi
mkdir $JBOSS_HOME

unzip /home/homer/Downloads/jboss-eap-7.3.0.zip -d $INSTALL_DIR

unzip -o /home/homer/Downloads/rhpam-7.8.0-business-central-eap7-deployable.zip -d $INSTALL_DIR

rm -rf /tmp/kie
# unzip kie-server
unzip /home/homer/Downloads/rhpam-7.8.0-kie-server-ee8.zip -d /tmp/kie
# kie-server
cp -r /tmp/kie/kie-server.war $JBOSS_HOME/standalone/deployments/
# .dodeploy
touch $JBOSS_HOME/standalone/deployments/kie-server.war.dodeploy

\cp -fr /tmp/kie/SecurityPolicy $JBOSS_HOME/bin

# create jboss admin user for console

$JBOSS_HOME/bin/add-user.sh --user jboss --password jboss123!

# create admin user for business central

$JBOSS_HOME/bin/add-user.sh -a --user bc-admin --password jboss123! --role admin,rest-all,kie-server

# cretae normal user for business central

$JBOSS_HOME/bin/add-user.sh -a --user bc-approver --password jboss123! --role approver,rest-all,kie-server

# start jboss
$JBOSS_HOME/bin/standalone.sh -c standalone-full.xml> /dev/null 2>&1 &
#$JBOSS_HOME/bin/standalone.sh -c standalone-full.xml

# wait for jboss to start 
LOGFILE="/opt/jboss-eap-7.3/standalone/log/server.log"

PATTERN="JBoss EAP.*started\ in"
echo "waiting for JBoss to start ..."
while read LINE; do
    if [[ $LINE =~ $PATTERN ]]; then
        echo "JBoss started!"
        break
    fi
done < <(tail -F $LOGFILE)

# add module, jdbc-driver, datasource, system properties

$JBOSS_HOME/bin/jboss-cli.sh --connect <<EOF
batch
module add --name=com.oracle.jdbc --resources=/usr/share/java/ojdbc8.jar --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=oracle:add(driver-name=oracle,driver-module-name=com.oracle.jdbc,driver-xa-datasource-class-name=oracle.jdbc.xa.client.OracleXADataSource)
data-source add --name=OracleDS --jndi-name=java:jboss/OracleDS --driver-name=oracle --connection-url=jdbc:oracle:thin:@localhost:1521:cdb1 --user-name=c##bart --password=bart1987 --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.oracle.OracleValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.oracle.OracleExceptionSorter --stale-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.oracle.OracleStaleConnectionChecker
/system-property=org.kie.server.location:add(value="http://localhost:8080/kie-server/services/rest/server")
/system-property=org.kie.server.controller:add(value="http://localhost:8080/business-central/rest/controller")
/system-property=org.kie.server.controller.user:add(value="bc-admin")
/system-property=org.kie.server.controller.pwd:add(value="jboss123!")
/system-property=org.kie.server.user:add(value="bc-admin")
/system-property=org.kie.server.pwd:add(value="jboss123!")
/system-property=org.kie.server.id:add(value="default-kieserver")
/system-property=org.kie.server.persistence.ds:add(value="java:jboss/OracleDS")
/system-property=org.kie.server.persistence.dialect:add(value="org.hibernate.dialect.Oracle10gDialect")
run-batch
exit
EOF

# stop jboss
echo "Stopping jboss..."
$JBOSS_HOME/bin/jboss-cli.sh --connect command=:shutdown
if [ $? -ne 0 ]
  then echo "Failed to gracefully stop JBoss."
fi
                                                              1,1           Top

