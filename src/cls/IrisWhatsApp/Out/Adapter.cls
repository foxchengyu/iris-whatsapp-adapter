/// Outbound adapter for the WhatsApp Cloud API.
///
/// This adapter communicates with Meta's Graph API to send WhatsApp messages,
/// mark messages as read, and query message status. It builds proper JSON
/// payloads, sets <code>Authorization: Bearer</code> headers, and handles TLS
/// auto-configuration and proxy support consistent with the broader
/// iris-whatsapp-adapter project.
///
/// <h3>Configuration</h3>
/// <ul>
///   <li><var>AccessToken</var> — WhatsApp Cloud API permanent or temporary
///       access token (required).</li>
///   <li><var>PhoneNumberID</var> — The phone-number-id from your WhatsApp
///       Business Account (required).</li>
///   <li><var>ApiVersion</var> — Meta Graph API version, default "v22.0".</li>
///   <li><var>SSLConfiguration</var> — Optional TLS config name. When empty the
///       adapter auto-creates a client configuration.</li>
///   <li><var>ProxyServer</var> — Optional HTTP proxy, for example
///       "proxy.example.com:8080".</li>
/// </ul>
/// <h3>Environment Variable Fallback</h3>
/// When settings are not provided in the production configuration the adapter
/// reads <code>WA_ACCESS_TOKEN</code>, <code>WA_PHONE_NUMBER_ID</code> and
/// <code>WA_PROXY</code> from the container environment.
Class IrisWhatsApp.Out.Adapter Extends Ens.OutboundAdapter
{

/// WhatsApp Cloud API permanent or temporary access token.
Property AccessToken As %String;

/// Phone Number ID from the WhatsApp Business Account.
Property PhoneNumberID As %String;

/// Meta Graph API version.
Property ApiVersion As %String [ InitialExpression = "v22.0" ];

/// Name of a TLS / SSL configuration. Auto-created when empty.
Property SSLConfiguration As %String;

/// Optional HTTP proxy, for example "proxy.example.com:8080".
Property ProxyServer As %String;

/// Cached resolved TLS configuration name.
Property ResolvedSSL As %String [ Private ];

/// Read credential settings from environment variables when they are not
/// already set in the production configuration.
Method OnInit() As %Status
{
    If ..AccessToken = "" {
        Set ..AccessToken = $System.Util.GetEnviron("WA_ACCESS_TOKEN")
    }
    If ..PhoneNumberID = "" {
        Set ..PhoneNumberID = $System.Util.GetEnviron("WA_PHONE_NUMBER_ID")
    }
    If ..ProxyServer = "" {
        Set ..ProxyServer = $System.Util.GetEnviron("WA_PROXY")
    }
    Quit ##super()
}

// ---------- public API ----------

/// Send a text message and return the parsed JSON response from Meta.
/// <var>pTo</var> must be in international format, e.g. "8613800138000".
Method SendText(pTo As %String, pBody As %String, pPreviewUrl As %Boolean = 0) As %DynamicObject
{
    Set tPayload = ##class(%DynamicObject).%New()
    Do tPayload.%Set("messaging_product", "whatsapp")
    Do tPayload.%Set("recipient_type", "individual")
    Do tPayload.%Set("to", pTo)
    Do tPayload.%Set("type", "text")
    Set tText = ##class(%DynamicObject).%New()
    Do tText.%Set("preview_url", pPreviewUrl)
    Do tText.%Set("body", pBody)
    Do tPayload.%Set("text", tText)
    Set tPath = "/" _ ..ApiVersion _ "/" _ ..PhoneNumberID _ "/messages"
    Quit ..PostAPI(tPath, tPayload)
}

/// Send a template message. <var>pComponents</var> is an optional dynamic array
/// of component objects (header / body / button parameters).
Method SendTemplate(pTo As %String, pTemplateName As %String, pLanguage As %String = "en", pComponents As %DynamicArray = "") As %DynamicObject
{
    Set tPayload = ##class(%DynamicObject).%New()
    Do tPayload.%Set("messaging_product", "whatsapp")
    Do tPayload.%Set("recipient_type", "individual")
    Do tPayload.%Set("to", pTo)
    Do tPayload.%Set("type", "template")
    Set tTemplate = ##class(%DynamicObject).%New()
    Do tTemplate.%Set("name", pTemplateName)
    Set tLanguage = ##class(%DynamicObject).%New()
    Do tLanguage.%Set("code", pLanguage)
    Do tTemplate.%Set("language", tLanguage)
    If $IsObject(pComponents) && (pComponents.%Size() > 0) {
        Do tTemplate.%Set("components", pComponents)
    }
    Do tPayload.%Set("template", tTemplate)
    Set tPath = "/" _ ..ApiVersion _ "/" _ ..PhoneNumberID _ "/messages"
    Quit ..PostAPI(tPath, tPayload)
}

/// Send an interactive message (list, reply buttons, or CTA URL).
/// <var>pInteractive</var> is the interactive-object per the WhatsApp API spec.
Method SendInteractive(pTo As %String, pInteractive As %DynamicObject) As %DynamicObject
{
    Set tPayload = ##class(%DynamicObject).%New()
    Do tPayload.%Set("messaging_product", "whatsapp")
    Do tPayload.%Set("recipient_type", "individual")
    Do tPayload.%Set("to", pTo)
    Do tPayload.%Set("type", "interactive")
    If $IsObject(pInteractive) {
        Do tPayload.%Set("interactive", pInteractive)
    }
    Set tPath = "/" _ ..ApiVersion _ "/" _ ..PhoneNumberID _ "/messages"
    Quit ..PostAPI(tPath, tPayload)
}

/// Mark an incoming message as read.
Method MarkAsRead(pMessageId As %String) As %DynamicObject
{
    Set tPayload = ##class(%DynamicObject).%New()
    Do tPayload.%Set("messaging_product", "whatsapp")
    Do tPayload.%Set("status", "read")
    Do tPayload.%Set("message_id", pMessageId)
    Set tPath = "/" _ ..ApiVersion _ "/" _ ..PhoneNumberID _ "/messages"
    Quit ..PostAPI(tPath, tPayload)
}

/// Download media (image, audio, document) given a media ID. Returns the raw
/// bytes as a stream.
Method DownloadMedia(pMediaId As %String, Output pContentType As %String) As %Stream.GlobalBinary
{
    Set tPath = "/" _ ..ApiVersion _ "/" _ pMediaId
    Set tURL = "https://graph.facebook.com" _ tPath _ "?access_token=" _ ..AccessToken
    Set http = ..NewRequest()
    Do http.RemoveHeader("Content-Type")
    Set sc = http.Get(tURL)
    If $System.Status.IsError(sc) {
        Do ##class(IrisWhatsApp.Utils).Fail("Media download failed: " _ $System.Status.GetErrorText(sc))
    }
    If http.HttpResponse.StatusCode '= 200 {
        Do ##class(IrisWhatsApp.Utils).Fail("Media download HTTP " _ http.HttpResponse.StatusCode)
    }
    Set pContentType = http.HttpResponse.GetHeader("Content-Type")
    Quit http.HttpResponse.Data
}

/// Retrieve the download URL for a media ID (public for 5 minutes).
Method GetMediaURL(pMediaId As %String) As %DynamicObject
{
    Set tPath = "/" _ ..ApiVersion _ "/" _ pMediaId
    Quit ..GetAPI(tPath)
}

// ---------- HTTP helpers ----------

/// Create a %Net.HttpRequest preconfigured for Meta Graph API with the correct
/// TLS, proxy, and header settings.
Method NewRequest() As %Net.HttpRequest
{
    Set http = ##class(%Net.HttpRequest).%New()
    Set http.Server = "graph.facebook.com"
    Set http.Port = 443
    Set http.Https = 1
    Set tls = ..ResolveTLS()
    If tls '= "" {
        Set http.SSLConfiguration = tls
    }
    Do ..ApplyProxy(http)
    Do http.SetHeader("Authorization", "Bearer " _ ..AccessToken)
    Do http.SetHeader("Content-Type", "application/json")
    Do http.SetHeader("User-Agent", "iris-whatsapp-adapter/1.0")
    Quit http
}

/// Resolve the SSL/TLS configuration to use.
Method ResolveTLS() As %String
{
    If ..ResolvedSSL '= "" {
        Quit ..ResolvedSSL
    }
    Set name = ##class(IrisWhatsApp.TLS).Ensure(..SSLConfiguration)
    Set ..ResolvedSSL = name
    Quit name
}

/// Apply proxy settings to a request. When the proxy URL includes
/// <code>://</code> the scheme prefix is stripped before use.
Method ApplyProxy(http As %Net.HttpRequest)
{
    If ..ProxyServer = "" {
        Quit
    }
    Set addr = ..ProxyServer
    If addr [ "://" {
        Set addr = $Piece(addr, "://", 2)
    }
    Set addr = $Piece(addr, "/", 1)
    Set host = addr
    Set port = 8080
    If addr [ ":" {
        Set host = $Piece(addr, ":", 1)
        Set port = +$Piece(addr, ":", 2)
    }
    If host = "" {
        Quit
    }
    Set http.ProxyServer = host
    Set http.ProxyPort = port
    Set http.ProxyTunnel = 1
    Set http.ProxyHTTPS = 1
}

/// POST a JSON payload and return the parsed response.
Method PostAPI(pPath As %String, pPayload As %DynamicObject, pTimeout As %Integer = 30) As %DynamicObject
{
    Set http = ..NewRequest()
    Set http.Timeout = pTimeout
    Set tBody = pPayload.%ToJSON()
    Set http.EntityBody = tBody
    Set sc = http.Post("https://graph.facebook.com" _ pPath)
    If $System.Status.IsError(sc) {
        Throw ##class(%Exception.General).%New("WhatsApp", 5001, "", "HTTP POST error: " _ $System.Status.GetErrorText(sc))
    }
    Set tResp = ..ParseResponse(http)
    Quit tResp
}

/// GET from the Graph API and return the parsed response.
Method GetAPI(pPath As %String, pTimeout As %Integer = 30) As %DynamicObject
{
    Set http = ..NewRequest()
    Do http.RemoveHeader("Content-Type")
    Set http.Timeout = pTimeout
    Set sc = http.Get("https://graph.facebook.com" _ pPath)
    If $System.Status.IsError(sc) {
        Throw ##class(%Exception.General).%New("WhatsApp", 5002, "", "HTTP GET error: " _ $System.Status.GetErrorText(sc))
    }
    Set tResp = ..ParseResponse(http)
    Quit tResp
}

/// Parse the HTTP response body as JSON and check for Meta error objects.
Method ParseResponse(http As %Net.HttpRequest) As %DynamicObject
{
    Set tBody = ##class(IrisWhatsApp.Utils).ReadStream(http.HttpResponse.Data)
    Set tCode = http.HttpResponse.StatusCode
    Set tObj = ""
    Try {
        Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch ex {
        Throw ##class(%Exception.General).%New("WhatsApp", 5003, "", "Invalid JSON from Meta API (HTTP " _ tCode _ "): " _ $Extract(tBody, 1, 300))
    }
    If tCode >= 300 {
        Set tErr = tObj.%Get("error")
        Set tMsg = $Select($IsObject(tErr): tErr.%Get("message"), 1: tBody)
        Throw ##class(%Exception.General).%New("WhatsApp", 5004, "", "Meta API error HTTP " _ tCode _ ": " _ tMsg)
    }
    Quit tObj
}

}