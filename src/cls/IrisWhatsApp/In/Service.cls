/// Business Service that processes incoming WhatsApp messages.
///
/// Messages arrive from the <class>IrisWhatsApp.Webhook</class> CSP handler
/// via <method>ProcessInput</method>. Wire this service to a Business Process
/// or routing rule in your production to handle inbound WhatsApp traffic.
///
/// <h3>Routing</h3>
/// The service emits <class>IrisWhatsApp.Msg.WebhookRequest</class> instances.
/// Configure a routing rule or forward target on the service configuration to
/// direct incoming messages to a handler process.
Class IrisWhatsApp.In.Service Extends Ens.BusinessService
{

Parameter ADAPTER = "Ens.InboundAdapter";

/// Process an incoming WhatsApp message forwarded from the webhook handler.
Method OnProcessInput(pInput As IrisWhatsApp.Msg.WebhookRequest, Output pOutput As Ens.Response) As %Status
{
    Set pOutput = ##class(Ens.Response).%New()
    Set tMsgId = pInput.MessageId
    If tMsgId '= "" {
        Write !, "[WhatsApp] Message from ", pInput.From, " — ", $Extract(pInput.Body, 1, 80)
    }
    Quit $System.Status.OK()
}

}