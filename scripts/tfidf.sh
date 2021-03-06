#!/usr/bin/env bash

###############################################################################
# This script is used to perform TF-IDF as a sequence of 3 MapReduce jobs.
#
# Usage:
# ./run_tfidf.sh <input_dir> <output_dir> [conf]
#
# where:
# input_dir = HDFS Directory with the input files
# output_dir = HDFS Directory to place the output
# conf = Optional hadoop configuration options
#
# This script will create three directories under <output_dir>, namely,
# tfidf1, tfidf2, and tfidf3, to place to output from each MR job.
#
# Examples:
# ./run_tfidf.sh ~/input ~/output "-conf=myconf.xml"
# ./run_tfidf.sh ~/input ~/output "-Dmapred.reduce.tasks=2"
#
# Author: Herodotos Herodotou
# Date: November 5, 2010
##############################################################################


# Make sure we have all the arguments
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
printf "./run_tfidf.sh <input_dir> <output_dir> [conf]\n"
   printf " input_dir = HDFS Directory with the input files\n"
   printf " output_dir = HDFS Directory to place the output\n"
   printf " conf = Optional hadoop configuration options\n"
   exit -1
fi

# arguments: no of deployed tasktrackers

$SCRIPTS_HOME/check_env.sh
if [ $? -ne 0 ]
then
    echo "Environment not configured properly. Check env.sh and source it."
    exit 1
fi

JOBTRACKER=`cat $HADOOP_HOME/conf/jobtracker.txt`
CLIENT=`cat $HADOOP_HOME/conf/client.txt`

oarsh $JOBTRACKER "source $SCRIPTS_HOME/env.sh; $HADOOP_HOME/bin/stop-mapred.sh"
oarsh $JOBTRACKER "killall java"
sleep 10

$SCRIPTS_HOME/hdfs-deploy.sh

oarsh $JOBTRACKER "source $SCRIPTS_HOME/env.sh; $HADOOP_HOME/bin/start-mapred.sh"
echo "Deployment done"
sleep 30

mkdir -p $APPS_LOGS/sort_logs

oarsh $CLIENT "source $SCRIPTS_HOME/env.sh; $HADOOP_HOME/bin/hadoop fs -put $FILE $HFILE"

oarsh $CLIENT "source $SCRIPTS_HOME/env.sh; $HADOOP_HOME/bin/hadoop fs -rmr $HFILE/_logs; $HADOOP_HOME/bin/hadoop fs -ls $HFILE"

sleep 10

# Get the input data
declare INPUT=$1;
declare OUTPUT=$2;
declare CONFIG=$3;

# Remove the output directories
${HADOOP_HOME}/bin/hadoop fs -rmr $OUTPUT/tfidf1 >& /dev/null
${HADOOP_HOME}/bin/hadoop fs -rmr $OUTPUT/tfidf2 >& /dev/null
${HADOOP_HOME}/bin/hadoop fs -rmr $OUTPUT/tfidf3 >& /dev/null

# Execute the jobs
printf "\nExecuting Job 1: Word Frequency in Doc\n"
${HADOOP_HOME}/bin/hadoop jar $EXAMPLE_JAR tf-idf-1 $CONFIG $HFILE $OUTPUT/tfidf1

printf "\nExecuting Job 2: Word Counts For Docs\n"
${HADOOP_HOME}/bin/hadoop jar $EXAMPLE_JAR tf-idf-2 $CONFIG $OUTPUT/tfidf1 $OUTPUT/tfidf2

printf "\nExecuting Job 3: Docs In Corpus and TF-IDF\n"
${HADOOP_HOME}/bin/hadoop jar $EXAMPLE_JAR tf-idf-3 $CONFIG $HFILE $OUTPUT/tfidf2 $OUTPUT/tfidf3
