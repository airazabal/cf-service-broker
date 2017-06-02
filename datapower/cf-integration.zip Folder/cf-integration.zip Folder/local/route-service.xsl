<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dpgui="http://www.datapower.com/extensions/webgui"
                xmlns:dp="http://www.datapower.com/extensions"
                xmlns:str="http://exslt.org/strings"
                xmlns:dpfunc="http://www.datapower.com/extensions/functions"
                xmlns:func="http://exslt.org/functions"
                extension-element-prefixes="dp"  exclude-result-prefixes="dp" version="1.0">

  <xsl:template match="/">

    <xsl:variable name="config" select="document('route-service-config.xml')"/>

    <!-- fetch the headers from the CF Router used for routing and validation. -->
    <xsl:variable name="forwardedURLHeader" select="dp:http-request-header('X-CF-Forwarded-Url')"/> 
    <xsl:variable name="signatureHeader" select="dp:http-request-header('X-CF-Proxy-Signature')"/> 
    <xsl:variable name="metadataHeader" select="dp:http-request-header('X-CF-Proxy-Metadata')"/> 

    <xsl:variable name="uri" select="dpfunc:getCompleteURI()"/>
    <xsl:variable name="url" select="dpfunc:getURL()"/>
    <xsl:variable name="parsed-url-in" select="dpfunc:parseURL($url)"/>

    <!-- Set the next hop to be the URL of the APIc GW rewritten with more info
         about the CF service. -->
    <xsl:variable name="parsed-cf-url" select="dpfunc:parseURL($forwardedURLHeader)"/>

    <dp:dump-nodes file="'parsed-cf-url.xml'" nodes="$parsed-cf-url"/>
    <xsl:message dp:type="mpgw" dp:priority="error">parsed cf=[<xsl:copy-of select="$parsed-cf-url"/>]</xsl:message>


    <xsl:variable name="nextHopHost">
        <xsl:choose>
            <xsl:when test="$config/routeservice/apigwhost">
                <xsl:value-of select="$config/routeservice/apigwhost"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$parsed-cf-url/parsed-url/host"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="nextHopPort">
        <xsl:choose>
            <xsl:when test="$config/routeservice/apigwport">
                <xsl:value-of select="concat(':', $config/routeservice/apigwport)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$parsed-cf-url/parsed-url/port"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="nextHopPath">
        <xsl:choose>
            <xsl:when test="$config/routeservice/pathasquery = 'true'">
                <xsl:value-of select="concat(':', $parsed-cf-url/parsed-url/path)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="normalized-path-1">
                <xsl:choose>
                    <xsl:when test="substring($parsed-url-in/parsed-url/path, string-length($parsed-url-in/parsed-url/path)) = '/'">
                        <xsl:value-of select="substring($parsed-url-in/parsed-url/path, 1, string-length($parsed-url-in/parsed-url/path)-1)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="string($parsed-url-in/parsed-url/path)"/>
                    </xsl:otherwise>
                </xsl:choose>
                </xsl:variable>
                <xsl:value-of select="concat($normalized-path-1, $parsed-cf-url/parsed-url/path)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="nextHopQuery">
        <xsl:variable name="combinedQuery">
            <xsl:choose>
                <xsl:when test="not($parsed-cf-url/parsed-url/query = '')">
                    <xsl:choose>
                        <xsl:when test="not($parsed-url-in/parsed-url/query = '')">
                            <xsl:value-of select="concat($parsed-cf-url/parsed-url/query, '&amp;', substring-after($parsed-url-in/parsed-url/query, '?'))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$parsed-cf-url/parsed-url/query"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$parsed-url-in/parsed-url/query"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="not($config/routeservice/pathasquery = 'true')">
                <xsl:value-of select="$combinedQuery" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($combinedQuery, '&amp;CF-Orig-Path=', $parsed-url-in/parsed-url/path)" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="nextRoute" select="concat('https://', $nextHopHost, $nextHopPort, $nextHopPath, $nextHopQuery)"/>

    <dp:set-variable name="'var://service/routing-url'" value="$nextRoute"/>

    <!-- Forward the url, signature, and metadata headers on to the API GW -->
    <dp:set-http-request-header name="'X-CF-Forwarded-Url'" value="$forwardedURLHeader"/>
    <dp:set-http-request-header name="'X-CF-Proxy-Signature'" value="$signatureHeader"/>
    <dp:set-http-request-header name="'X-CF-Proxy-Metadata'" value="$metadataHeader"/>

  </xsl:template>

    <func:function name="dpfunc:getURL">
        <!-- Get the current URL. -->
        <xsl:variable name="url" select="dp:variable('var://service/URL-in')"/>
        
        <!-- decode the URL in case it is URL encoded. -->
        <xsl:variable name="url-decoded" select="dp:decode($url,'url')"/>
        <func:result select="string($url-decoded)"/>
    
    </func:function>

    <!--+
        |*******************************
        |*** Extension Function
        |*** Name: dpfunc:getCompleteURI
        |*******************************
        +-->
        
    <func:function name="dpfunc:getCompleteURI">
        <!-- Get the current URI. -->

        <xsl:variable name="uri" select="dp:variable('var://service/URI')"/>
        <!-- decode the URI in case it is URL encoded. -->
        <xsl:variable name="uri-decoded" select="dp:decode($uri,'url')"/>
        <func:result select="string($uri-decoded)"/>

    </func:function>

    <func:function name="dpfunc:parseURL">
        <xsl:param name="url" />

        <xsl:variable name="scheme">
            <xsl:choose>
                <xsl:when test="contains($url, '://')">
                   <xsl:value-of select="substring($url, 1, string-length(substring-before($url, '://'))+3)" />
                </xsl:when>
                <xsl:when test="contains($url, ':')">
                    <xsl:value-of select="substring($url, 1, string-length(substring-before($url, ':'))+1)" />
                </xsl:when>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="user">
            <xsl:variable name="nextPart" select="substring($url, 1+string-length($scheme))" />
            <xsl:if test="contains($nextPart, '@')">
                <xsl:value-of select="substring($nextPart, 1, string-length(substring-before($nextPart, '@'))+1)" />
            </xsl:if>
        </xsl:variable>

        <xsl:variable name="host">
            <xsl:variable name="nextPart" select="substring($url, 1+string-length($scheme)+string-length($user))" />
<xsl:message dp:type="mpgw" dp:priority="error">parsing host nextPart=[<xsl:value-of select="$nextPart"/>]</xsl:message>

            <xsl:choose>
                <!-- is there a port? -->
                <xsl:when test="contains($nextPart, ':')">
                <xsl:message dp:type="mpgw" dp:priority="error">contains : =[<xsl:value-of select="substring-before($nextPart, ':')"/>]</xsl:message>
                    <xsl:value-of select="substring-before($nextPart, ':')" />
                </xsl:when>
                <!-- is a path next? -->
                <xsl:when test="contains($nextPart, '/')">
                    <xsl:value-of select="substring-before($nextPart, '/')" />
                </xsl:when>
                <!-- goes straight to query parms? -->
                <xsl:when test="contains($nextPart, '?')">
                    <xsl:value-of select="substring-before($nextPart, '?')" />
                </xsl:when>
                <!-- All host and nothing else -->
                <xsl:otherwise>
                    <xsl:message dp:type="mpgw" dp:priority="error">does not contains : </xsl:message>
                    <xsl:value-of select="$nextPart" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="port">
            <xsl:variable name="nextPart" select="substring($url, 1+string-length($scheme)+string-length($user)+string-length($host))" />
            <xsl:choose>
                <xsl:when test="starts-with($nextPart, ':')">
                    <xsl:choose>
                        <!-- Check for slash -->
                        <xsl:when test="string-length(substring-before($nextPart, '/'))">
                            <xsl:value-of select="substring($nextPart, 1, string-length(substring-before($nextPart, '/')))" />
                        </xsl:when>
                        <!-- Check for query parms -->
                        <xsl:when test="string-length(substring-before($nextPart, '?'))">
                            <xsl:value-of select="substring($nextPart, 1, string-length(substring-before($nextPart, '?')))" />
                        </xsl:when>
                        <!-- All port -->
                        <xsl:otherwise>
                           <xsl:value-of select="$nextPart" />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="path">
            <xsl:variable name="nextPart" select="substring($url, 1+string-length($scheme)+string-length($user)+string-length($host)+string-length($port))" />
            <xsl:choose>
                <!-- Check for query parms -->
                <xsl:when test="string-length(substring-before($nextPart, '?'))">
                    <xsl:value-of select="substring($nextPart, 1, string-length(substring-before($nextPart, '?')))" />
                </xsl:when>
                <!-- All path -->
                <xsl:otherwise>
                    <xsl:value-of select="$nextPart" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="query">
            <xsl:value-of select="substring($url, 1+string-length($scheme)+string-length($user)+string-length($host)+string-length($port)+string-length($path))" />
        </xsl:variable>

        <xsl:variable name="parsed-url">
            <parsed-url>
                <scheme><xsl:value-of select="$scheme"/></scheme>
                <user><xsl:value-of select="$user"/></user>
                <host><xsl:value-of select="$host"/></host>
                <port><xsl:value-of select="$port"/></port>
                <path><xsl:value-of select="$path"/></path>
                <query><xsl:value-of select="$query"/></query>
            </parsed-url>
        </xsl:variable>

        <func:result select="$parsed-url"/>

    </func:function>

</xsl:stylesheet>
