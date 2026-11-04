/// Response from the WhatsApp Cloud API after sending a message.
Class IrisWhatsApp.Msg.SendResponse Extends Ens.Response
{

/// WhatsApp message ID assigned by Meta, for example "wamid.HBgL...".
Property MessageId As %String(MAXLEN = 128);

/// "sent" when the API accepted the message, or "error" on failure.
Property Status As %String(MAXLEN = 20);

/// Full JSON response body from the Cloud API, useful for debugging.
Property RawResponse As %String(MAXLEN = "");

Storage Default
{
<Data name="SendResponseDefaultData">
<Subscript>"SendResponse"</Subscript>
<Value name="1">
<Value>MessageId</Value>
</Value>
<Value name="2">
<Value>Status</Value>
</Value>
<Value name="3">
<Value>RawResponse</Value>
</Value>
</Data>
<DefaultData>SendResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}