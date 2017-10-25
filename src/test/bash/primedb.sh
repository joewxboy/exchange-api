#!/bin/bash

# Prime an empty DB with a few resources useful for testing with

#if [[ $1 == "-h" || $1 == "--help" ]]; then
#	echo "Usage: $0 [<name base>]"
#	exit 0
#fi
#
if [[ -z $EXCHANGE_ROOTPW ]]; then
    echo "Error: env var EXCHANGE_ROOTPW must be set and it must match what is in the exchange's config.json file"
    exit 2
fi
namebase=""

# Test configuration. You can override these before invoking the script, if you want.
EXCHANGE_URL_ROOT="${EXCHANGE_URL_ROOT:-http://localhost:8080}"
EXCHANGE_ORG="${EXCHANGE_ORG:-myorg}"
EXCHANGE_USER="${EXCHANGE_USER:-me}"
EXCHANGE_PW="${EXCHANGE_PW:-mypw}"
EXCHANGE_EMAIL="${EXCHANGE_EMAIL:-me@email.com}"
EXCHANGE_NODEAUTH="${EXCHANGE_NODEAUTH:-'n1:abc123'}"
EXCHANGE_AGBOTAUTH="${EXCHANGE_AGBOTAUTH:-'a1:abcdef'}"

appjson="application/json"
accept="-H Accept:$appjson"
content="-H Content-Type:$appjson"

rootauth="root/root:$EXCHANGE_ROOTPW"

orgid=$EXCHANGE_ORG
orgid2="org2"

user="$EXCHANGE_USER"
pw=$EXCHANGE_PW
userauth="$EXCHANGE_ORG/$user:$pw"
email=$EXCHANGE_EMAIL
userauthorg2="$orgid2/$user:$pw"

nodeid=$(echo "$EXCHANGE_NODEAUTH" | cut -d: -f 1)
nodetoken=$(echo "$EXCHANGE_NODEAUTH" | cut -d: -f 2)
nodeauth="$EXCHANGE_ORG/$nodeid:$nodetoken"
nodeid2="n2"
nodeauth2="$EXCHANGE_ORG/$nodeid2:$nodetoken"

agbotid=$(echo "$EXCHANGE_AGBOTAUTH" | cut -d: -f 1)
agbottoken=$(echo "$EXCHANGE_AGBOTAUTH" | cut -d: -f 2)
agbotauth="$EXCHANGE_ORG/$agbotid:$agbottoken"

agreementbase="${namebase}agreement"
agreementid1="${agreementbase}1"
agreementid1b="${agreementbase}1b"
agreementid2="${agreementbase}2"

microid="bluehorizon.network-microservices-network_1.0.0_amd64"
microurl="https://bluehorizon.network/microservices/network"
microarch="amd64"
microversion="1.0.0"

microid2="bluehorizon.network-microservices-rtlsdr_2.0.0_amd64"
microurl2="https://bluehorizon.network/microservices/rtlsdr"
microarch2="amd64"
microversion2="2.0.0"

workid="bluehorizon.network-workloads-netspeed_1.0.0_amd64"
workurl="https://bluehorizon.network/workloads/netspeed"
workarch="amd64"
workversion="1.0.0"
workid2="bluehorizon.network-workloads-weather_1.0.0_amd64"
workurl2="https://bluehorizon.network/workloads/weather"

patid="p1"

bctypeid="bct1"

blockchainid="bc1"

#curlBasicArgs="-s -w %{http_code} --output /dev/null $accept"
curlBasicArgs="-s -w %{http_code} $accept"
# curlBasicArgs="-s -f"
# set -x

# Check the http code returned by curl. Args: returned rc, good rc, second good rc (optional)
function checkrc {
    out="$1"
    httpcode=${out:$((${#out}-3))}    # the last 3 chars are the http code
    #echo "httpcode=$httpcode"
    if [[ $httpcode != $2 && ( -z $3 ||  $httpcode != $3 ) ]]; then
	    #httpcode="${1:0:3}"     # when an error occurs with curl the rest method output comes in stderr with the http code
		echo "===> curl failed with: $out"
		#exit $httpcode
		exit 2
	fi
}

# Check the exit code of the cmd that was run
function checkexitcode {
	if [[ $1 != 0 ]]; then
		echo "===> commands failed with exit code $1, exiting."
		exit $1
	fi
}

# set -x

function curlfind {
    auth="$1"
    url=$2
	if [[ $auth != "" ]]; then
		auth="-H Authorization:Basic$auth"    # no spaces so we do not need to quote it
	fi
    #echo curl $curlBasicArgs $auth --output /dev/null $EXCHANGE_URL_ROOT/v1/$url
    rc=$(curl $curlBasicArgs $auth --output /dev/null $EXCHANGE_URL_ROOT/v1/$url 2>&1)
    #checkrc "$rc" 200 404  # <- do not do this inside curl find because it can not output an error msg (it gets gobbled up by the caller)
    echo "$rc"
}

function curlcreate {
    method=$1
    auth="$2"
    url=$3
    body=$4
	if [[ $auth != "" ]]; then
		auth="-H Authorization:Basic$auth"    # no spaces so we do not need to quote it
	fi
    echo curl -X $method $curlBasicArgs $content $auth -d "$body" $EXCHANGE_URL_ROOT/v1/$url
    rc=$(curl -X $method $curlBasicArgs $content $auth -d "$body" $EXCHANGE_URL_ROOT/v1/$url 2>&1)
    checkrc "$rc" 201
}

function curlputpost {
    method=$1
    auth=$2
    url=$3
    body="$4"
	auth="-H Authorization:Basic$auth"    # no spaces so we do not need to quote it
    if [[ $body == "" ]]; then
        echo curl -X $method $curlBasicArgs $auth $EXCHANGE_URL_ROOT/v1/$url
        rc=$(curl -X $method $curlBasicArgs $auth $EXCHANGE_URL_ROOT/v1/$url 2>&1)
    else
        echo curl -X $method $curlBasicArgs $content $auth -d "$body" $EXCHANGE_URL_ROOT/v1/$url
        rc=$(curl -X $method $curlBasicArgs $content $auth -d "$body" $EXCHANGE_URL_ROOT/v1/$url 2>&1)
    fi
    checkrc "$rc" 201
}

rc=$(curlfind "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid")
checkrc "$rc" 200 404
if [[ $rc == 404 ]]; then
    curlcreate "POST" "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid" '{"label": "An org", "description": "blah blah"}'
else
    echo "orgs/$orgid exists"
fi

rc=$(curlfind "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid2")
checkrc "$rc" 200 404
if [[ $rc == 404 ]]; then
    curlcreate "POST" "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid2" '{"label": "Another org", "description": "blah blah"}'
else
    echo "orgs/$orgid2 exists"
fi

rc=$(curlfind "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid/users/$user")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
        curlcreate "PUT" "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid/users/$user" '{"password": "'$pw'", "admin": true, "email": "'$email'"}'
else
    echo "orgs/$orgid/users/$user exists"
fi

rc=$(curlfind "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid2/users/$user")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
        curlcreate "PUT" "root/root:$EXCHANGE_ROOTPW" "orgs/$orgid2/users/$user" '{"password": "'$pw'", "admin": true, "email": "'$email'"}'
else
    echo "orgs/$orgid2/users/$user exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/microservices/$microid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauth "orgs/$orgid/microservices" '{"label": "Network x86_64", "description": "blah blah", "public": true, "specRef": "'$microurl'",
  "version": "'$microversion'", "arch": "'$microarch'", "sharable": "single", "downloadUrl": "",
  "matchHardware": {},
  "userInput": [],
  "workloads": [] }'
else
    echo "orgs/$orgid/microservices/$microid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/microservices/$microid2")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauth "orgs/$orgid/microservices" '{"label": "Network x86_64", "description": "blah blah", "public": true, "specRef": "'$microurl2'",
  "version": "'$microversion2'", "arch": "'$microarch2'", "sharable": "single", "downloadUrl": "",
  "matchHardware": {},
  "userInput": [],
  "workloads": [] }'
else
    echo "orgs/$orgid/microservices/$microid2 exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/workloads/$workid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauth "orgs/$orgid/workloads" '{"label": "Netspeed x86_64", "description": "blah blah", "public": true, "workloadUrl": "'$workurl'",
  "version": "'$workversion'", "arch": "'$workarch'", "downloadUrl": "",
  "apiSpec": [{ "specRef": "'$microurl'", "org": "'$orgid'", "version": "'$microversion'", "arch": "'$microarch'" }],
  "userInput": [],
  "workloads": [] }'
else
    echo "orgs/$orgid/workloads/$workid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/workloads/$workid2")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauth "orgs/$orgid/workloads" '{"label": "Weather x86_64", "description": "blah blah", "public": true, "workloadUrl": "'$workurl2'",
  "version": "1.0.0", "arch": "amd64", "downloadUrl": "",
  "apiSpec": [{ "specRef": "'$microurl'", "org": "'$orgid'", "version": "'$microversion'", "arch": "'$microarch'" }],
  "userInput": [],
  "workloads": [] }'
else
    echo "orgs/$orgid/workloads/$workid2 exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/patterns/$patid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauth "orgs/$orgid/patterns/$patid" '{"label": "My Pattern", "description": "blah blah", "public": true,
  "workloads": [
    {
      "workloadUrl": "'$workurl'",
      "workloadOrgid": "'$orgid'",
      "workloadArch": "'$workarch'",
      "workloadVersions": [
        {
          "version": "'$workversion'",
          "deployment_overrides": "{\"services\":{\"location\":{\"environment\":[\"USE_NEW_STAGING_URL=false\"]}}}",
          "deployment_overrides_signature": "a",
          "priority": {
            "priority_value": 50,
            "retries": 1,
            "retry_durations": 3600,
            "verified_durations": 52
          },
          "upgradePolicy": {
            "lifecycle": "immediate",
            "time": "01:00AM"
          }
        }
      ],
      "dataVerification": {
        "enabled": true,
        "URL": "",
        "user": "",
        "password": "",
        "interval": 240,
        "check_rate": 15,
        "metering": {
          "tokens": 1,
          "per_time_unit": "min",
          "notification_interval": 30
        }
      },
      "nodeHealth": {
        "missing_heartbeat_interval": 600,
        "check_agreement_status": 120
      }
    }
  ],
  "agreementProtocols": [{ "name": "Basic" }] }'
else
    echo "orgs/$orgid/patterns/$patid exists"
fi

rc=$(curlfind $userauthorg2 "orgs/$orgid2/patterns/$patid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "POST" $userauthorg2 "orgs/$orgid2/patterns/$patid" '{"label": "My other Pattern", "description": "blah blah", "public": true,
  "workloads": [],
  "agreementProtocols": [{ "name": "Basic" }] }'
else
    echo "orgs/$orgid2/patterns/$patid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/nodes/$nodeid" '{"token": "'$nodetoken'", "name": "rpi1", "pattern": "'$orgid'/'$patid'",
  "registeredMicroservices": [
    {
      "url": "'$microurl'",
      "numAgreements": 1,
      "policy": "{json policy for rpi1 netspeed}",
      "properties": [
        { "name": "arch", "value": "arm", "propType": "string", "op": "in" },
        { "name": "version", "value": "1.0.0", "propType": "version", "op": "in" }
      ]
    }
  ],
  "msgEndPoint": "", "softwareVersions": {}, "publicKey": "ABC" }'
else
    echo "orgs/$orgid/nodes/$nodeid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid2")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/nodes/$nodeid2" '{"token": "'$nodetoken'", "name": "rpi1", "pattern": "'$orgid'/'$patid'", "registeredMicroservices": [], "msgEndPoint": "", "softwareVersions": {}, "publicKey": "ABC" }'
else
    echo "orgs/$orgid/nodes/$nodeid2 exists"
fi

rc=$(curlfind $userauthorg2 "orgs/$orgid2/nodes/$nodeid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauthorg2 "orgs/$orgid2/nodes/$nodeid" '{"token": "'$nodetoken'", "name": "rpi1", "pattern": "'$orgid2'/'$patid'", "registeredMicroservices": [], "msgEndPoint": "", "softwareVersions": {}, "publicKey": "ABC" }'
else
    echo "orgs/$orgid2/nodes/$nodeid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid/status")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $nodeauth "orgs/$orgid/nodes/$nodeid/status" '{ "connectivity": {"firmware.bluehorizon.network": true}, "microservices": [], "workloads": [] }'
else
    echo "orgs/$orgid/nodes/$nodeid/status exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/agbots/$agbotid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/agbots/$agbotid" '{"token": "'$agbottoken'", "name": "agbot", "msgEndPoint": "whisper-id", "publicKey": "ABC"}'
else
    echo "orgs/$orgid/agbots/$agbotid exists"
fi

rc=$(curlfind $userauthorg2 "orgs/$orgid2/agbots/$agbotid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauthorg2 "orgs/$orgid2/agbots/$agbotid" '{"token": "'$agbottoken'", "name": "agbot", "msgEndPoint": "whisper-id", "publicKey": "ABC"}'
else
    echo "orgs/$orgid2/agbots/$agbotid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/agbots/$agbotid/patterns/${orgid}_$patid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/agbots/$agbotid/patterns/${orgid}_$patid" '{ "patternOrgid": "'$orgid'", "pattern": "'$patid'" }'
else
    echo "orgs/$orgid/agbots/$agbotid/patterns/${orgid}_$patid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $nodeauth "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1" '{"microservices": [], "workload": {"orgid": "'$orgid'", "pattern": "'$patid'", "url": "'$workurl'"}, "state": "negotiating"}'
else
    echo "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1 exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1b")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $nodeauth "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1b" '{"microservices": [], "workload": {"orgid": "'$orgid'", "pattern": "'$patid'", "url": "'$workurl2'"}, "state": "negotiating"}'
else
    echo "orgs/$orgid/nodes/$nodeid/agreements/$agreementid1b exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/nodes/$nodeid2/agreements/$agreementid2")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $nodeauth2 "orgs/$orgid/nodes/$nodeid2/agreements/$agreementid2" '{"microservices": [], "workload": {"orgid": "'$orgid'", "pattern": "'$patid'", "url": "'$workurl2'"}, "state": "negotiating"}'
else
    echo "orgs/$orgid/nodes/$nodeid2/agreements/$agreementid2 exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/agbots/$agbotid/agreements/$agreementid1")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $agbotauth "orgs/$orgid/agbots/$agbotid/agreements/$agreementid1" '{"workload": {"orgid": "'$orgid'", "pattern": "'$patid'", "url": "'$workurl'"}, "state": "negotiating"}'
else
    echo "orgs/$orgid/agbots/$agbotid/agreements/$agreementid1 exists"
fi

# Do not have a good way to know what msg id they will have, but it is ok to create additional msgs
curlputpost "POST" $agbotauth "orgs/$orgid/nodes/$nodeid/msgs" '{"message": "hey there", "ttl": 300}'
curlputpost "POST" $nodeauth "orgs/$orgid/agbots/$agbotid/msgs" '{"message": "hey there", "ttl": 300}'

rc=$(curlfind $userauth "orgs/$orgid/bctypes/$bctypeid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/bctypes/$bctypeid" '{"description": "abc", "details": "escaped json"}'
else
    echo "orgs/$orgid/bctypes/$bctypeid exists"
fi

rc=$(curlfind $userauth "orgs/$orgid/bctypes/$bctypeid/blockchains/$blockchainid")
checkrc "$rc" 200 404
if [[ $rc != 200 ]]; then
    curlcreate "PUT" $userauth "orgs/$orgid/bctypes/$bctypeid/blockchains/$blockchainid" '{"description": "abc", "public": true, "details": "escaped json"}'
else
    echo "orgs/$orgid/bctypes/$bctypeid/blockchains/$blockchainid exists"
fi

echo "All resources added successfully"
