#!/bin/bash
printf "getting jwt...\n\n"
jwt=`curl --insecure -s -u admin:password https://ubuntu-atscale.atscaledomain.com:10500/default/auth` > /dev/null
mdxquery="SELECT NON EMPTY Hierarchize({DrilldownLevel({[Product Dimension].[Product Dimension].[All]},,,INCLUDE_CALC_MEMBERS)}) DIMENSION PROPERTIES PARENT_UNIQUE_NAME,HIERARCHY_UNIQUE_NAME ON COLUMNS  FROM [Internet Sales Cube] WHERE ([Measures].[salesamount1]) CELL PROPERTIES VALUE, FORMAT_STRING, LANGUAGE, BACK_COLOR, FORE_COLOR, FONT_FLAGS";
printf "Exceuting MDX ...\n"
 cmd="curl --insecure -k -s -X POST \
          https://ubuntu-atscale.atscaledomain.com:10502/xmla/default \
          -H 'authorization: Bearer $jwt' \
          -H 'content-type: application/xml' \
          -d '<Envelope xmlns=\"http://schemas.xmlsoap.org/soap/envelope/\">
        <Body>
            <Execute xmlns=\"urn:schemas-microsoft-com:xml-analysis\">
                <Command>
                    <Statement>
                      <![CDATA[$mdxquery]]>
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
        eval $cmd &