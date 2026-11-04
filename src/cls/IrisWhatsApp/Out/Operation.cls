/// Business Operation that sends WhatsApp messages through the Meta Cloud API.
///
/// Wire this operation into any InterSystems IRIS production to send text,
/// template, or interactive WhatsApp messages. The operation delegates all
/// HTTP communication to <class>IrisWhatsApp.Out.Adapter</class>.
///
/// <h3>Message Types</h3>
/// <table>
///   <tr><th>Request Class</th><th>Method</th></tr>
///   <tr><td>IrisWhatsApp.Msg.TextRequest</td><td>SendText</td></tr>
/// </table>
Class IrisWhatsApp.Out.Operation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "IrisWhatsApp.Out.Adapter";

Parameter INVOCATION = "Queue";

/// Send a text message. Receives an <class>IrisWhatsApp.Msg.TextRequest</class>
/// and returns an <class>IrisWhatsApp.Msg.SendResponse</class>.
Method SendText(pRequest As IrisWhatsApp.Msg.TextRequest, Output pResponse As IrisWhatsApp.Msg.SendResponse) As %Status
{
    Set pResponse = ##class(IrisWhatsApp.Msg.SendResponse).%New()
    Set tStart = $Horolog
    Try {
        Set tResult = ..Adapter.SendText(pRequest.To, pRequest.Body, pRequest.PreviewUrl)
        Set tMsgs = tResult.%Get("messages")
        If $IsObject(tMsgs) && (tMsgs.%Size() > 0) {
            Set pResponse.MessageId = tMsgs.%Get(0).%Get("id")
            Set pResponse.Status = "sent"
        } Else {
            Set pResponse.Status = "error"
        }
        Set pResponse.RawResponse = tResult.%ToJSON()
    } Catch ex {
        Set pResponse.Status = "error"
        Set pResponse.RawResponse = ex.DisplayString()
    }
    Set pResponse.ElapsedTime = ##class(IrisWhatsApp.Utils).ElapsedSeconds(tStart)
    Quit $System.Status.OK()
}

}