/// CSP REST handler for WhatsApp Cloud API webhooks.
///
/// Exposes a single endpoint that Meta calls for webhook verification (GET)
/// and message delivery (POST). The endpoint is reachable at
/// <code>/csp/whatsapp/IrisWhatsApp.Webhook.cls/whatsapp</code> after the CSP
/// application is created by <class>IrisWhatsApp.Setup</class>.
///
/// <h3>Verification (GET)</h3>
/// Meta sends <code>hub.mode=subscribe</code>, <code>hub.verify_token</code>
/// and <code>hub.challenge</code>. The handler returns the challenge string and
/// HTTP 200 when the token matches, or 403 otherwise.
///
/// <h3>Message delivery (POST)</h3>
/// Meta sends a JSON payload containing one or more WhatsApp messages. The
/// handler parses each message into an
/// <class>IrisWhatsApp.Msg.WebhookRequest</class> and forwards it to the
/// production's InboundService.
Class IrisWhatsApp.Webhook Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "UTF-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/whatsapp" Method="GET" Call="HandleVerification"/>
  <Route Url="/whatsapp" Method="POST" Call="HandleMessage"/>
  <Route Url="/test" Method="GET" Call="HandleTest"/>
</Routes>
}

// ---------- verification ----------

/// GET /whatsapp — webhook verification handshake.
ClassMethod HandleVerification() As %Status
{
    Set tMode = $Get(%request.Data("hub.mode", 1))
    Set tToken = $Get(%request.Data("hub.verify_token", 1))
    Set tChallenge = $Get(%request.Data("hub.challenge", 1))

    If tMode '= "subscribe" {
        Set %response.Status = "400 Bad Request"
        Do %response.Write("{""error"":""invalid hub.mode""}")
        Quit $System.Status.OK()
    }

    Set tExpected = ..GetVerifyToken()
    If tToken '= tExpected {
        Set %response.Status = "403 Forbidden"
        Do %response.Write("{""error"":""verify_token mismatch""}")
        Quit $System.Status.OK()
    }

    Set %response.ContentType = "text/plain"
    Do %response.Write(tChallenge)
    Quit $System.Status.OK()
}

// ---------- message delivery ----------

/// POST /whatsapp — receive incoming WhatsApp messages from Meta.
ClassMethod HandleMessage() As %Status
{
    Set tBody = ""
    If $IsObject(%request.Content) {
        Do %request.Content.Rewind()
        While '%request.Content.AtEnd {
            Set tBody = tBody _ %request.Content.Read(32768)
        }
    }

    If tBody = "" {
        Set %response.Status = "400 Bad Request"
        Do %response.Write("{""error"":""empty body""}")
        Quit $System.Status.OK()
    }

    Try {
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch ex {
        Set %response.Status = "400 Bad Request"
        Do %response.Write("{""error"":""invalid JSON""}")
        Quit $System.Status.OK()
    }

    // Only process messages from WhatsApp Business Account
    If tPayload.%Get("object") '= "whatsapp_business_account" {
        Set %response.Status = "200 OK"
        Do %response.Write("OK")
        Quit $System.Status.OK()
    }

    Set tEntries = tPayload.%Get("entry")
    If $IsObject(tEntries) {
        For i = 0:1:tEntries.%Size() - 1 {
            Set tEntry = tEntries.%Get(i)
            Set tChanges = tEntry.%Get("changes")
            If $IsObject(tChanges) {
                For j = 0:1:tChanges.%Size() - 1 {
                    Do ..ProcessChange(tChanges.%Get(j))
                }
            }
        }
    }

    Set %response.Status = "200 OK"
    Do %response.Write("OK")
    Quit $System.Status.OK()
}

// ---------- health check ----------

/// GET /test — quick health check that returns the service status.
ClassMethod HandleTest() As %Status
{
    Set %response.ContentType = "text/plain"
    Set tRunning = ##class(Ens.Director).IsProductionRunning()
    Do %response.Write("iris-whatsapp-adapter webhook is up. Production: " _ $Select(tRunning: "running", 1: "stopped"))
    Quit $System.Status.OK()
}

// ---------- internal ----------

/// Parse a single change object and forward any messages to the production.
ClassMethod ProcessChange(pChange As %DynamicObject)
{
    Set tValue = pChange.%Get("value")
    If '$IsObject(tValue) {
        Quit
    }

    // Extract metadata
    Set tMetadata = tValue.%Get("metadata")
    Set tBizPhone = ""
    Set tBizPhoneID = ""
    If $IsObject(tMetadata) {
        Set tBizPhone = tMetadata.%Get("display_phone_number")
        Set tBizPhoneID = tMetadata.%Get("phone_number_id")
    }

    // Extract messages
    Set tMessages = tValue.%Get("messages")
    If '$IsObject(tMessages) {
        Quit
    }

    // Extract contacts (sender names)
    Set tContacts = tValue.%Get("contacts")
    Set tContactNames = ##class(%DynamicObject).%New()
    If $IsObject(tContacts) {
        For c = 0:1:tContacts.%Size() - 1 {
            Set tContact = tContacts.%Get(c)
            Set tName = tContact.%Get("profile").%Get("name")
            Set tWaId = tContact.%Get("wa_id")
            If tName '= "" {
                Do tContactNames.%Set(tWaId, tName)
            }
        }
    }

    For k = 0:1:tMessages.%Size() - 1 {
        Set tMsg = tMessages.%Get(k)
        Do ..ForwardMessage(tMsg, tBizPhone, tBizPhoneID, tContactNames)
    }
}

/// Build a WebhookRequest and forward it into the production.
ClassMethod ForwardMessage(pMsg As %DynamicObject, pBizPhone As %String, pBizPhoneID As %String, pContactNames As %DynamicObject)
{
    Set tRequest = ##class(IrisWhatsApp.Msg.WebhookRequest).%New()
    Set tRequest.From = pMsg.%Get("from")
    Set tRequest.To = pBizPhone
    Set tRequest.MessageId = pMsg.%Get("id")
    Set tRequest.Timestamp = pMsg.%Get("timestamp")
    Set tRequest.MediaType = pMsg.%Get("type")

    // Extract text body
    Set tType = pMsg.%Get("type")
    If tType = "text" {
        Set tText = pMsg.%Get("text")
        If $IsObject(tText) {
            Set tRequest.Body = tText.%Get("body")
        }
    }

    // Store the full raw payload for custom processing
    Set tStream = ##class(%Stream.GlobalCharacter).%New()
    Do tStream.Write(pMsg.%ToJSON())
    Set tRequest.RawPayload = tStream

    // Forward to the inbound service in the production
    Set tProduction = "IrisWhatsApp.Production"
    Set tService = "IrisWhatsApp.In.Service"

    If '##class(Ens.Director).IsProductionRunning() {
        Write !, "[Webhook] Production not running, message from ", tRequest.From, " dropped"
        Quit
    }

    // Check if the target is configured in the production
    Set tFound = 0
    Set tConf = ##class(Ens.Config.Production).%OpenId(tProduction)
    If $IsObject(tConf) {
        For ii = 1:1:tConf.Items.Count() {
            Set tItem = tConf.Items.GetAt(ii)
            If tItem.Name = tService {
                Set tFound = 1
                Quit
            }
        }
    }

    If 'tFound {
        Write !, "[Webhook] Service '", tService, "' not found in production '", tProduction, "'"
        Quit
    }

    // Send to the business service
    Set tSC = ##class(Ens.Director).CreateBusinessService(tService, .tSvc)
    If $System.Status.IsOK(tSC) {
        Set tSC = tSvc.ProcessInput(tRequest, .tResponse)
        If $System.Status.IsError(tSC) {
            Write !, "[Webhook] Error processing message: ", $System.Status.GetErrorText(tSC)
        }
    } Else {
        Write !, "[Webhook] Could not create business service '", tService, "': ", $System.Status.GetErrorText(tSC)
    }
}

/// Reads the verify token from environment, falling back to production config.
ClassMethod GetVerifyToken() As %String
{
    // Try environment first
    Set tToken = $System.Util.GetEnviron("WA_VERIFY_TOKEN")
    If tToken '= "" {
        Quit tToken
    }

    // Try reading from the adapter in the production
    Set tProduction = "IrisWhatsApp.Production"
    Set tConf = ##class(Ens.Config.Production).%OpenId(tProduction)
    If '$IsObject(tConf) {
        Quit ""
    }

    For i = 1:1:tConf.Items.Count() {
        Set tItem = tConf.Items.GetAt(i)
        If tItem.ClassName = "IrisWhatsApp.Out.Operation" {
            Set tSettings = tItem.Settings
            For s = 1:1:tSettings.Count() {
                Set tSetting = tSettings.GetAt(s)
                If tSetting.Name = "AccessToken" {
                    Set tToken = tSetting.Value
                    // The verify token is a separate setting - fallback to env
                }
            }
        }
    }

    Quit ""
}

}