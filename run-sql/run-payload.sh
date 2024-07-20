export jwt=`curl --insecure -s -X GET -u admin:password "https://ubuntu-atscale.atscaledomain.com:10500/default/auth"`

curl --insecure -X POST \
-H "Authorization: Bearer $jwt" \
-H "Content-Type: application/xml" \
--data @payload.xml \
https://ubuntu-atscale.atscaledomain.com:10502/xmla/default
