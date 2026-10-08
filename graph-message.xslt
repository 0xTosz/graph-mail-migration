<?xml version="1.0" encoding="UTF-8"?>
<!-- inubit IBISMime -> body for POST /v1.0/users/{mailbox}/mailFolders/inbox/messages
     Attachments are uploaded separately afterwards, see graph-attachments.xslt -->

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/IBISMime">
    <xsl:variable name="h" select="Header"/>

    <!-- Body = first HTML part, else first plain-text part, else the message itself (single-part mail).
         Keep in sync with graph-attachments.xslt, which treats every other leaf part as an attachment. -->
    <xsl:variable name="textParts" select=".//Part[not(Part)][not(Header[@name = 'content-disposition'][starts-with(lower-case(@value), 'attachment')])]"/>
    <xsl:variable name="html" select="$textParts[Header[@name = 'content-type'][lower-case(@value) = 'text/html']][1]"/>
    <xsl:variable name="plain" select="$textParts[Header[@name = 'content-type'][lower-case(@value) = 'text/plain']][1]"/>
    <xsl:variable name="bodyPart" select="($html, $plain, .)[1]"/>

    <xsl:variable name="prio" select="lower-case(($h[@name = 'importance']/@value, $h[@name = 'x-priority']/@value)[1])"/>
    <xsl:variable name="sensitivity" select="lower-case($h[@name = 'sensitivity'][1]/@value)"/>

    <object>
      <string name="subject"><xsl:value-of select="$h[@name = 'subject'][1]/@value"/></string>

      <object name="body">
        <string name="contentType"><xsl:value-of select="if ($bodyPart/Header[@name = 'content-type'][lower-case(@value) = 'text/html']) then 'HTML' else 'Text'"/></string>
        <string name="content"><xsl:value-of select="$bodyPart/Content"/></string>
      </object>

      <!-- Single address: "Name <addr>" or bare addr. Sender falls back to From. -->
      <xsl:for-each select="'from', 'sender'">
        <xsl:variable name="value" select="string(($h[@name = current()]/@value, $h[@name = 'from']/@value)[1])"/>
        <xsl:if test="$value != ''">
          <object name="{.}">
            <object name="emailAddress">
              <string name="address"><xsl:value-of select="if (contains($value, '&lt;')) then substring-before(substring-after($value, '&lt;'), '&gt;') else normalize-space($value)"/></string>
              <xsl:if test="normalize-space(replace(substring-before($value, '&lt;'), '&quot;', '')) != ''">
                <string name="name"><xsl:value-of select="normalize-space(replace(substring-before($value, '&lt;'), '&quot;', ''))"/></string>
              </xsl:if>
            </object>
          </object>
        </xsl:if>
      </xsl:for-each>

      <!-- Address lists: comma-separated, names may be quoted and contain commas -->
      <xsl:for-each select="'to', 'cc', 'bcc', 'reply-to'">
        <xsl:variable name="field" select="."/>
        <xsl:variable name="i" select="position()"/>
        <xsl:if test="$h[@name = $field]">
          <array name="{('toRecipients', 'ccRecipients', 'bccRecipients', 'replyTo')[$i]}">
            <xsl:analyze-string select="string-join($h[@name = $field]/@value, ',')"
                regex="((&quot;[^&quot;]*&quot;|[^&quot;,&lt;])*)&lt;([^&gt;]+)&gt;|([^\s,&lt;&gt;&quot;]+@[^\s,&lt;&gt;&quot;]+)">
              <xsl:matching-substring>
                <object>
                  <object name="emailAddress">
                    <string name="address"><xsl:value-of select="(regex-group(3)[. != ''], regex-group(4))[1]"/></string>
                    <xsl:if test="normalize-space(replace(regex-group(1), '&quot;', '')) != ''">
                      <string name="name"><xsl:value-of select="normalize-space(replace(regex-group(1), '&quot;', ''))"/></string>
                    </xsl:if>
                  </object>
                </object>
              </xsl:matching-substring>
            </xsl:analyze-string>
          </array>
        </xsl:if>
      </xsl:for-each>

      <!-- Importance: high/normal/low, or X-Priority 1-5 -->
      <xsl:if test="$prio">
        <string name="importance"><xsl:value-of select="if (matches($prio, '^(high|urgent|1|2)')) then 'high' else if (matches($prio, '^(low|non-urgent|4|5)')) then 'low' else 'normal'"/></string>
      </xsl:if>

      <xsl:if test="$h[@name = 'message-id']">
        <string name="internetMessageId"><xsl:value-of select="normalize-space($h[@name = 'message-id'][1]/@value)"/></string>
      </xsl:if>

      <boolean name="isReadReceiptRequested"><xsl:value-of select="exists($h[@name = 'disposition-notification-to'])"/></boolean>
      <boolean name="isDeliveryReceiptRequested"><xsl:value-of select="exists($h[@name = 'return-receipt-to'])"/></boolean>

      <array name="singleValueExtendedProperties">
        <!-- PR_MESSAGE_FLAGS: 0 = unread, 1 = read; either way not a draft -->
        <object>
          <string name="id">Integer 0x0E07</string>
          <string name="value">0</string>
        </object>

        <!-- Sensitivity: 1 personal, 2 private, 3 confidential -->
        <xsl:if test="$sensitivity = ('personal', 'private', 'company-confidential')">
          <object>
            <string name="id">Integer 0x0036</string>
            <string name="value"><xsl:value-of select="index-of(('personal', 'private', 'company-confidential'), $sensitivity)"/></string>
          </object>
        </xsl:if>

        <!-- Threading -->
        <xsl:if test="$h[@name = 'in-reply-to']">
          <object>
            <string name="id">String 0x1042</string>
            <string name="value"><xsl:value-of select="normalize-space($h[@name = 'in-reply-to'][1]/@value)"/></string>
          </object>
        </xsl:if>
        <xsl:if test="$h[@name = 'references']">
          <object>
            <string name="id">String 0x1039</string>
            <string name="value"><xsl:value-of select="normalize-space($h[@name = 'references'][1]/@value)"/></string>
          </object>
        </xsl:if>
        <xsl:if test="$h[@name = 'thread-topic']">
          <object>
            <string name="id">String 0x0070</string>
            <string name="value"><xsl:value-of select="$h[@name = 'thread-topic'][1]/@value"/></string>
          </object>
        </xsl:if>
        <xsl:if test="$h[@name = 'thread-index']">
          <object>
            <string name="id">Binary 0x0071</string>
            <string name="value"><xsl:value-of select="normalize-space($h[@name = 'thread-index'][1]/@value)"/></string>
          </object>
        </xsl:if>

        <!-- Original header block rebuilt from the Header elements (shown in Outlook's message details) -->
        <object>
          <string name="id">String 0x007D</string>
          <string name="value"><xsl:value-of select="string-join(for $x in $h return concat($x/@name, ': ', $x/@value,
              string-join(for $p in $x/Parameter return concat('; ', $p/@name, '=&quot;', $p/@value, '&quot;'), '')), '&#13;&#10;')"/></string>
        </object>
      </array>
    </object>
  </xsl:template>

</xsl:stylesheet>
