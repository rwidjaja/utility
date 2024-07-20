#!/bin/bash
#usage ./export.sh <admin-login> <admin-pw> <atscale url> <org> <backup/migrate/single> <new-host>
#
#
#/*
# * Copyright AtScale, Inc. 2016. All Rights Reserved.
# *
# * No part of this project or any of its contents may be reproduced, copied,
# * modified or adapted, without the prior written consent of AtScale, Inc..
# */
# Version 2019.1
# Rudy Widjaja
# https://github.com/AtScaleInc/apidemo/tree/master/export-script
#---------------------------------------------------------------------------------------------------
# V1: allow bulk import/export
# V2: allow single import/export
# V3: allow https to http
# V4: added update script by bhavik
#---------------------------------------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed. Aborting."; exit 1; }

if (($# < 4)); then
    echo "-----------------------------------------------------------------------------------------------------"
    echo "--- You must enter at least 5 parameters"
    echo "--- <admin-login> <admin-pw> <atscale url> <org> <options> <new-host>"
    echo "--- the options are"
    echo "--- backup-only : to do a full backup of atscale projects into XML file"
    echo "--- full-migration : to do a full migration from one cluster to another atscale cluster"
    echo "--- single-migration : to do a selective copy of project to another atscale cluster"
    echo "--- Examples: "
    echo "--- export.sh admin admin https://atscale-master.hostname.com <org/orgid> full-migration https://atscale-standby.hostname.com <org/orgid>"
    echo "--- export.sh admin admin https://atscale-master.hostname.com default backup-only"
    echo "--- export.sh admin admin https://atscale-master.hostname.com <org/orgid> single-migration https://atscale-standby.hostname.com <org/orgid>"
    echo "--- export.sh admin admin https://atscale-master.hostname.com <org/orgid> single-update https://atscale-standby.hostname.com <org/orgid>"
    echo "--- The script will generate list of available Project, then copy and paste the Project Name Then hit Enter"
    echo "--- "
    echo "-----------------------------------------------------------------------------------------------------"
    exit 1
fi

# Assigning variables
userid=$1
userpw=$2
master_host=$3
org1=$4
yn=$5
standby_host=$6
org2=$7

# Function to get JWT token
get_jwt() {
  curl --insecure -k -s -X GET -u $1:$2 "$3:10500/$4/auth"
}

# Function to clean up generated files
cleanup() {
  rm ${1#*//}-$2-$(date +%m-%d-%Y)/projects.list
}

# Function to display project list
display_list() {
  printf "Current Project\n"
  printf "===============\n"
  while read p; do
    ProjectName="$(cut -d'|' -f1 <<<"$p")"
    echo $ProjectName
  done < ${1#*//}-$2-$(date +%m-%d-%Y)/projects.list
}

# Function to generate project list
generate_list() {
  jwt=$(get_jwt $1 $2 $3 $4)
  mkdir ${3#*//}-$4-$(date +%m-%d-%Y)
  cmd="curl --insecure -k -s -H \"authorization: bearer $jwt\" $3:10500/api/1.0/org/$4/projects | jq -r '.response[] | (.name) + \"|\" + (.id)'"
  eval $cmd > ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list
}

# Function for bulk XML export
bulk_xml_export() {
  jwt=$(get_jwt $1 $2 $3 $4)
  while read p; do
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    echo "curl --insecure -k -s -H \"authorization: bearer $jwt\" $3:10500/org/$4/project/$ProjectId/xml/download" > ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file
  done < ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list

  while read p; do
    PName="$(cut -d'|' -f1 <<<"$p")"
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    sh ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file > ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.xml
    echo "Downloading Project: $PName"
    rm ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file
  done < ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list
}

# Function for bulk project deletion
bulk_delete() {
  jwt=$(get_jwt $1 $2 $3 $4)
  jwt2=$(get_jwt $1 $2 $5 $6)

  while read p; do
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    PName="$(cut -d'|' -f1 <<<"$p")"
    while read t; do
      PSource="$(cut -d'|' -f1 <<<"$t")"
      if [ "$PName" == "$PSource" ]; then
        cmd="curl --insecure -k -X DELETE -s -H \"authorization: bearer $jwt2\" $5:10500/api/1.0/org/$6/project/$ProjectId"
        eval $cmd > /dev/null
        echo "  - Removing Project: $PSource from: $5"
      fi
    done < ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list
  done < ${5#*//}-$4-$(date +%m-%d-%Y)/projects.list
}

# Function for bulk XML import
bulk_xml_import() {
  jwt=$(get_jwt $1 $2 $5 $6)
  echo "Executing bulk Import"

  while read p; do
    PName="$(cut -d'|' -f1 <<<"$p")"
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    cmd="curl --insecure -k -X POST --form \"key=key1=value1\" -F file=@${3#*//}-$6-$(date +%m-%d-%Y)/$ProjectId.xml -s -H \"authorization: bearer $jwt\" $5:10500/api/1.0/org/$6/file/import"
    eval $cmd > /dev/null
    echo "Copying $PName to: $5"
  done < ${3#*//}-$6-$(date +%m-%d-%Y)/projects.list
}

# Function for single XML export
single_xml_export() {
  IFS=''
  jwt=$(get_jwt $1 $2 $3 $4)
  echo "Source From: $3"

  while read p; do
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    PName="$(cut -d'|' -f1 <<<"$p")"
    if [ "$PName" == "$6" ]; then
      echo "curl --insecure -k -s -H \"authorization: bearer $jwt\" $3:10500/org/$4/project/$ProjectId/xml/download" > ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file
      sh ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file > ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.xml
      echo "Exporting Project Name: $PName with UID: $ProjectId"
      rm ${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.file
    fi
  done < ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list
}

# Function for single XML delete
single_xml_delete() {
  IFS=''
  jwt=$(get_jwt $1 $2 $5 $4)
  jwt2=$(get_jwt $1 $2 $5 $6)

  while read p; do
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    PName="$(cut -d'|' -f1 <<<"$p")"
    if [ "$PName" == "$7" ]; then
      cmd="curl --insecure -k -X DELETE -s -H \"authorization: bearer $jwt2\" $5:10500/api/1.0/org/$6/project/$ProjectId"
      eval $cmd > /dev/null
      echo "Deleting Project Name: $PName"
    fi
  done < ${5#*//}-$6-$(date +%m-%d-%Y)/projects.list
}

# Function for single XML import
single_xml_import() {
  IFS=''
  jwt=$(get_jwt $1 $2 $5 $6)

  while read p; do
    ProjectId="$(cut -d'|' -f2 <<<"$p")"
    PName="$(cut -d'|' -f1 <<<"$p")"
    if [ "$PName" == "$7" ]; then
      cmd="curl --insecure -k -X POST --form \"key=key1=value1\" -F file=@${3#*//}-$4-$(date +%m-%d-%Y)/$ProjectId.xml -s -H \"authorization: bearer $jwt\" $5:10500/api/1.0/org/$6/file/import"
      eval $cmd > /dev/null
      echo "Importing Project: $PName"
    fi
  done < ${3#*//}-$4-$(date +%m-%d-%Y)/projects.list
}

# Main Logic
case $yn in
  "backup-only")
    echo "Execute full backup of all projects"
    generate_list $userid $userpw $master_host $org1
    display_list $master_host $org1
    bulk_xml_export $userid $userpw $master_host $org1
    ;;
  "full-migration")
    echo "Execute full backup and copy to new cluster"
    generate_list $userid $userpw $master_host $org1
    display_list $master_host $org1
    bulk_xml_export $userid $userpw $master_host $org1
    bulk_delete $userid $userpw $master_host $org1 $standby_host $org2
    generate_list $userid $userpw $standby_host $org2
    bulk_xml_import $userid $userpw $master_host $org1 $standby_host $org2
    ;;
  "single-migration")
    echo "Execute single project migration to new cluster"
    echo "Please enter the Project Name to be copied to another cluster: "
    read projectName
    generate_list $userid $userpw $master_host $org1
    single_xml_export $userid $userpw $master_host $org1 $projectName
    generate_list $userid $userpw $standby_host $org2
    single_xml_delete $userid $userpw $standby_host $org2 $projectName
    single_xml_import $userid $userpw $master_host $org1 $standby_host $org2 $projectName
    ;;
  "single-update")
    echo "Execute single project update to new cluster"
    echo "Please enter the Project Name to be updated: "
    read projectName
    generate_list $userid $userpw $master_host $org1
    single_xml_export $userid $userpw $master_host $org1 $projectName
    generate_list $userid $userpw $standby_host $org2
    single_xml_delete $userid $userpw $standby_host $org2 $projectName
    single_xml_import $userid $userpw $master_host $org1 $standby_host $org2 $projectName
    ;;
  *)
    echo "Invalid option: $yn. Please choose from backup-only, full-migration, single-migration, or single-update."
    exit 1
    ;;
esac

cleanup $master_host $org1

