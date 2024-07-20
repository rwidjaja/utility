#!/bin/bash
if [ $# -ne 1 ]
  then
    printf "usage: ./mdxqry.sh http(s)://atscale-ha-node-01(or 02).docker.infra.atscale.com\n"
    printf " Example: \n"
    printf "./mdxqry.sh http://atscale-ha-node-01.docker.infra.atscale.com\n"
    printf " OR \n"
    printf "./mdxqry.sh http://atscale-ha-node-02.docker.infra.atscale.com\n"
    exit
fi
printf "getting jwt...\n\n"
jwt=`curl --insecure -k -s  -u admin:password \
  $1:10500/default/auth` > /dev/null
  echo $jwt
printf "...Exceuting query\n\n"
    cmd="curl --insecure -k -s -X POST \
          $1:10502/xmla/default \
          -H 'authorization: Bearer $jwt' \
          -H 'content-type: application/xml' \
          -d '<Envelope xmlns=\"http://schemas.xmlsoap.org/soap/envelope/\">
        <Body>
            <Execute xmlns=\"urn:schemas-microsoft-com:xml-analysis\">
   <Command>
       <Statement>
      <![CDATA[
	  SELECT NON EMPTY Hierarchize({DrilldownLevel({[Product Dimension].[Product Dimension].[All]},,,
	  INCLUDE_CALC_MEMBERS)}) DIMENSION PROPERTIES PARENT_UNIQUE_NAME,HIERARCHY_UNIQUE_NAME ON COLUMNS  
	  FROM [Internet Sales Cube] WHERE ([Measures].[salesamount1]) 
	  CELL PROPERTIES VALUE, FORMAT_STRING, LANGUAGE, BACK_COLOR, FORE_COLOR, FONT_FLAGS
]]>
       </Statement>
   </Command>
   <Properties>
       <PropertyList>
           <Catalog>Sales Insights</Catalog>
       </PropertyList>
   </Properties>
            </Execute>
        </Body>
        </Envelope>' > /dev/null"
        eval $cmd 