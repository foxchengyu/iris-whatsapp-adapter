/// Request message for sending a WhatsApp text message.
/// Send this to the <class>IrisWhatsApp.Out.Operation</class> to deliver a
/// WhatsApp message.
Class IrisWhatsApp.Msg.TextRequest Extends Ens.Request
{

/// Recipient phone number in international format, for example "8613800138000".
Property To As %String(MAXLEN = 30) [ Required ];

/// The text body of the message. WhatsApp supports up to 4096 characters.
Property Body As %String(MAXLEN = 4096) [ Required ];

/// Whether the first URL in the body should generate a link preview.
Property PreviewUrl As %Boolean [ InitialExpression = 0 ];

Storage Default
{
<Data name="TextRequestDefaultData">
<Subscript>"TextRequest"</Subscript>
<Value name="1">
<Value>To</Value>
</Value>
<Value name="2">
<Value>Body</Value>
</Value>
<Value name="3">
<Value>PreviewUrl</Value>
</Value>
</Data>
<DefaultData>TextRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}