/// Carries an incoming WhatsApp message parsed from the Meta webhook.
/// Produced by <class>IrisWhatsApp.Webhook</class> and forwarded into the
/// InterSystems IRIS production for routing and processing.
Class IrisWhatsApp.Msg.WebhookRequest Extends Ens.Request
{

/// Sender phone number, for example "8613800138000".
Property From As %String(MAXLEN = 30);

/// The business phone number that received the message.
Property To As %String(MAXLEN = 30);

/// Message text body (populated for text messages).
Property Body As %String(MAXLEN = 4096);

/// WhatsApp message ID assigned by Meta.
Property MessageId As %String(MAXLEN = 128);

/// Unix timestamp of the message, as sent by Meta.
Property Timestamp As %String(MAXLEN = 20);

/// Media type: "text", "image", "audio", "video", "document", "location", etc.
Property MediaType As %String(MAXLEN = 20);

/// Full JSON payload from the webhook, stored for reference or custom parsing.
Property RawPayload As %Stream.GlobalCharacter;

Storage Default
{
<Data name="WebhookRequestDefaultData">
<Subscript>"WebhookRequest"</Subscript>
<Value name="1">
<Value>From</Value>
</Value>
<Value name="2">
<Value>To</Value>
</Value>
<Value name="3">
<Value>Body</Value>
</Value>
<Value name="4">
<Value>MessageId</Value>
</Value>
<Value name="5">
<Value>Timestamp</Value>
</Value>
<Value name="6">
<Value>MediaType</Value>
</Value>
<Value name="7">
<Value>RawPayload</Value>
</Value>
</Data>
<DefaultData>WebhookRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}