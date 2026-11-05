/// One-shot setup that creates the webhook CSP application on first start.
/// Idempotent — safe to call on every boot.
Class IrisWhatsApp.Setup Extends %RegisteredObject
{

/// Run the full setup: CSP application and TLS configuration.
ClassMethod Run() As %Status
{
    Write !, "=== iris-whatsapp-adapter setup ==="
    Do ..EnsureTLS()
    Do ..EnsureCSPApp()
    Write !, "=== setup complete ===", !
    Write !, "To start the production:"
    Write !, "  Management Portal → Productions → IrisWhatsApp.Production → Start"
    Write !, "  Or: Set sc = ##class(Ens.Director).StartProduction(""IrisWhatsApp.Production"")"
    Write !, !
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
        Set tProps("NameSpace") = "USER"
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
        Set tProps("UseCookies") = 2
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

}