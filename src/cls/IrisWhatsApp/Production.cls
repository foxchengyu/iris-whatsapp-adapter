/// Sample production for the WhatsApp adapter.
///
/// Contains one outbound <class>IrisWhatsApp.Out.Operation</class> for sending
/// WhatsApp messages and one inbound <class>IrisWhatsApp.In.Service</class> for
/// processing incoming webhook messages.
///
/// Start this production from the Management Portal or via
/// <method>Ens.Director.StartProduction</method>.
Class IrisWhatsApp.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="IrisWhatsApp.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>WhatsApp Cloud API adapter — send and receive messages</Description>
  <ActorPoolSize>2</ActorPoolSize>

  <Item Name="WhatsAppOut" Category="WhatsApp" ClassName="IrisWhatsApp.Out.Operation" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Sends WhatsApp messages">
  </Item>

  <Item Name="IrisWhatsApp.In.Service" Category="WhatsApp" ClassName="IrisWhatsApp.In.Service" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Receives incoming WhatsApp webhook messages">
  </Item>
</Production>
}

Storage Default
{
<Data name="ProductionDefaultData">
<Subscript>"Production"</Subscript>
<Value name="1">
<Value>ProductionDefinition</Value>
</Value>
</Data>
<DefaultData>ProductionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}