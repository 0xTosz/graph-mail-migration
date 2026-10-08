<?xml version="1.0" encoding="UTF-8"?>
<!-- inubit IBISMime -> one <attachment> per attachment part, for upload sessions:

     <attachments>
       <attachment>
         <object>...</object>   converter input: body for POST .../messages/{id}/attachments/createUploadSession
         <size>...</size>       decoded size in bytes, for Content-Range
         <content>...</content> base64 without whitespace; slice into 3,932,160-char chunks (= 2,949,120 bytes), decode, PUT
       </attachment>
     </attachments>
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/IBISMime">
    <!-- Same body selection as graph-message.xslt; every other leaf part is an attachment -->
    <xsl:variable name="textParts" select=".//Part[not(Part)][not(Header[@name = 'content-disposition'][starts-with(lower-case(@value), 'attachment')])]"/>
    <xsl:variable name="html" select="$textParts[Header[@name = 'content-type'][lower-case(@value) = 'text/html']][1]"/>
    <xsl:variable name="plain" select="$textParts[Header[@name = 'content-type'][lower-case(@value) = 'text/plain']][1]"/>

    <attachments>
      <xsl:for-each select=".//Part[not(Part)] except ($html | $plain)">
        <!-- Assumes Content holds base64 for binary parts - check with a real attachment -->
        <xsl:variable name="b64" select="translate(Content, '&#9;&#10;&#13; ', '')"/>
        <xsl:variable name="size" select="string-length($b64) idiv 4 * 3 - (if (ends-with($b64, '==')) then 2 else if (ends-with($b64, '=')) then 1 else 0)"/>
        <attachment>
          <object>
            <object name="AttachmentItem">
              <string name="attachmentType">file</string>
              <string name="name"><xsl:value-of select="(Header[@name = 'content-disposition']/Parameter[@name = 'filename']/@value,
                                                         Header[@name = 'content-type']/Parameter[@name = 'name']/@value,
                                                         concat('attachment', position()))[1]"/></string>
              <number name="size"><xsl:value-of select="$size"/></number>
              <string name="contentType"><xsl:value-of select="(Header[@name = 'content-type']/@value, 'application/octet-stream')[1]"/></string>
              <!-- Inline images: Content-ID without <>, so cid: links in the HTML body resolve -->
              <xsl:if test="Header[@name = 'content-id']">
                <string name="contentId"><xsl:value-of select="translate(Header[@name = 'content-id'][1]/@value, '&lt;&gt; ', '')"/></string>
                <boolean name="isInline">true</boolean>
              </xsl:if>
            </object>
          </object>
          <size><xsl:value-of select="$size"/></size>
          <content><xsl:value-of select="$b64"/></content>
        </attachment>
      </xsl:for-each>
    </attachments>
  </xsl:template>

</xsl:stylesheet>
