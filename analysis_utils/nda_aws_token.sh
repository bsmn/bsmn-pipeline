#!/bin/bash

show_usage() {
    cat <<EOF

Usage: nda_aws_token.sh [options]

Generate NIMH Data Archives AWS token.

    -h          display this help and exit
    -r file     read NDA credential from file
    -s file     save NDA credential to file

EOF
}

read_credential() {
    read -p "NDA username: " username
    read -p "NDA password: " -s password
    echo 
    password=$(echo -n "$password" | sha1sum | sed 's/ .*//')
}

write_credential() {
    echo "username=$username"
    echo "password=$password"
}

##############################################################################
# Parse Arguments
##############################################################################
while getopts ":hr:s:" opt; do
    case "$opt" in
        h ) show_usage; exit 0;;
        r ) nda_cred_f=$OPTARG;;
        s ) read_credential; write_credential > $OPTARG; exit 0;;
        \?) echo "Unknown option: -$OPTARG" >&2
            show_usage >&2; exit 1;;
        : ) echo "Missing option argrument for -$OPTARG" >&2
            show_usage >&2; exit 1;;
    esac
done

if [ -z $nda_cred_f ]; then
    read_credential
elif [ ! -e $nda_cred_f ]; then
    echo "$nda_cred_f file doesn't exist." >$2; exit 1
else
    source $nda_cred_f
fi

#username=baetj
#password=fb0dc634e9179ebc3460d7a2a8c05cc3905fa00f
server="https://ndar.nih.gov/DataManager/dataManager"

##############################################################################
# Make Request
##############################################################################
REQUEST_XML=$(cat <<EOF
<?xml version="1.0" ?>
<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
    <S:Body>
        <ns3:UserElement xmlns:ns4="http://dataManagerService"
                         xmlns:ns3="http://gov/nih/ndar/ws/datamanager/server/bean/jaxb"
                         xmlns:ns2="http://dataManager/transfer/model">
            <user>
                <id>0</id>
                <name>${username}</name>
                <password>${password}</password>
                <threshold>0</threshold>
            </user>
        </ns3:UserElement>
    </S:Body>
</S:Envelope>
EOF
)
RESPONSE_XML="$(curl -k -s --request POST -H "Content-Type: text/xml" -H "SOAPAction: \"generateToken\""  -d "$REQUEST_XML" $server)"

##############################################################################
# Handle Response
##############################################################################
ERROR=$(echo $RESPONSE_XML | grep -oP '(?<=<errorMessage>).*(?=</errorMessage>)')
if [ -n "$ERROR" ]; then
    echo "Error requesting token: $ERROR"
    exit 1;
fi

accessKey=$(echo $RESPONSE_XML | grep -oP '(?<=<accessKey>).*(?=</accessKey>)')
secretKey=$(echo $RESPONSE_XML | grep -oP '(?<=<secretKey>).*(?=</secretKey>)')
sessionToken=$(echo $RESPONSE_XML | grep -oP '(?<=<sessionToken>).*(?=</sessionToken>)')
expirationDate=$(echo $RESPONSE_XML | grep -oP '(?<=<expirationDate>).*(?=</expirationDate>)')


##############################################################################
# Write Token
##############################################################################
echo "export AWS_ACCESS_KEY_ID=$accessKey"
echo "export AWS_SECRET_ACCESS_KEY=$secretKey"
echo "export AWS_SESSION_TOKEN=$sessionToken"
