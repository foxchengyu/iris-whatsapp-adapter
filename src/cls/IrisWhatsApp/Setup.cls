/// One-shot setup that creates the webhook CSP application and a sample
/// production on first start. Idempotent — safe to call on every boot.
Class IrisWhatsApp.Setup Extends %RegisteredObject
{

/// Run the full setup: CSP application, web application, and production.
ClassMethod Run() As %Status
{
    Write !, "=== iris-whatsapp-adapter setup ==="
    Do ..EnsureTLS()
    Do ..EnsureCSPApp()
    Do ..StartProduction()
    Write !, "=== setup complete ===", !
    Quit $System.Status.OK()
}

/// Ensure the TLS client configuration exists.
ClassMethod EnsureTLS()
{
    Write !, "[TLS] ensuring client configuration ..."
    Set tName = ##class(IrisWhatsApp.TLS).Ensure()
    Write " ", $Select(tName = "": "FAILED", 1: tName)
}

/// Create the /csp/whatsapp web application if it doesn't already exist.
ClassMethod EnsureCSPApp()
{
    Write !, "[CSP] creating /csp/whatsapp web application ..."
    Set previous = $Namespace
    Try {
        Set $Namespace = "%SYS"
        Set tApp = "/csp/whatsapp"
        Set tExists = ##class(Security.Applications).Exists(tApp)
        If tExists {
            Set $Namespace = previous
            Write " already exists"
            Quit
        }
        // Create a minimal CSP application
        Set tProps("Name") = tApp
        Set tProps("Namespace") = "USER"
        Set tProps("Path") = "/opt/irisapp/csp/whatsapp"
        Set tProps("DispatchClass") = "IrisWhatsApp.Webhook"
        Set tProps("AutoCompile") = 1
        Set tProps("CookiePath") = tApp
        Set tProps("Description") = "WhatsApp Webhook"
        Set tProps("Enabled") = 1
        Set tProps("GroupById") = "%ALL"
        Set tProps("MatchRoles") = ":%All"
        Set tProps("Recurse") = 1
        Set tProps("ServeFiles") = 1
        Set tProps("CSPZENEnabled") = 1
        Set tProps("InbndWebServicesEnabled") = 1
        Set tProps("UseCookies") = 2  // Always
        Set tSC = ##class(Security.Applications).Create(tApp, .tProps)
        If $System.Status.IsOK(tSC) {
            Write " created"
        } Else {
            Write " FAILED: ", $System.Status.GetErrorText(tSC)
        }
    } Catch ex {
        Write " FAILED: ", ex.DisplayString()
    }
    Set $Namespace = previous
}

/// Start the sample production. Creates it from scratch if this is the first
/// run; otherwise just starts the existing one.
ClassMethod StartProduction()
{
    Write !, "[Production] starting ..."
    Set tProduction = "IrisWhatsApp.Production"

    Try {
        If '##class(Ens.Config.Production).%ExistsId(tProduction) {
            Do ..CreateProduction(tProduction)
            Write " created"
        }
        If '##class(Ens.Director).IsProductionRunning() {
            Set tSC = ##class(Ens.Director).StartProduction(tProduction)
            If $System.Status.IsOK(tSC) {
                Write ", started"
            } Else {
                Write ", start FAILED: ", $System.Status.GetErrorText(tSC)
            }
        } Else {
            Set tCurrent = ##class(Ens.Director).GetActiveProductionName()
            Write ", already running: ", tCurrent
        }
    } Catch ex {
        Write " FAILED: ", ex.DisplayString()
    }
}

/// Create a sample production with the WhatsApp operation and inbound service.
ClassMethod CreateProduction(pName As %String) As %Status
{
    Set tProduction = ##class(Ens.Config.Production).%New()
    Set tProduction.Name = pName
    Set tProduction.ActorPoolSize = 2

    // --- Outbound Operation ---
    Set tOp = ##class(Ens.Config.Item).%New()
    Set tOp.Name = "WhatsAppOut"
    Set tOp.ClassName = "IrisWhatsApp.Out.Operation"
    Set tOp.Category = "WhatsApp"
    Set tOp.PoolSize = 1
    Set tOp.Enabled = 1
    Do tProduction.Items.Insert(tOp)

    // --- Inbound Service ---
    Set tSvc = ##class(Ens.Config.Item).%New()
    Set tSvc.Name = "IrisWhatsApp.In.Service"
    Set tSvc.ClassName = "IrisWhatsApp.In.Service"
    Set tSvc.Category = "WhatsApp"
    Set tSvc.PoolSize = 1
    Set tSvc.Enabled = 1
    Do tProduction.Items.Insert(tSvc)

    // Save the production class
    Set tSC = tProduction.%Save()
    If $System.Status.IsError(tSC) {
        Write !, "[Production] Save failed: ", $System.Status.GetErrorText(tSC)
        Quit tSC
    }

    Write !, "[Production] created: ", pName
    Quit $System.Status.OK()
}

}