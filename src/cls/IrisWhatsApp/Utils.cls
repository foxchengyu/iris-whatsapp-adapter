/// Static utilities used across the WhatsApp adapter.
Class IrisWhatsApp.Utils Extends %RegisteredObject
{

/// Returns the current UTC timestamp for audit logging.
ClassMethod Now() As %String
{
    Quit $ZDateTime($Horolog, 3, 1)
}

/// Seconds elapsed since an earlier $Horolog value.
ClassMethod ElapsedSeconds(start As %String) As %Integer
{
    Quit $Select(start = "": 0, 1: ($Piece($Horolog, ",", 2) - $Piece(start, ",", 2)) + (($Piece($Horolog, ",", 1) - $Piece(start, ",", 1)) * 86400))
}

/// Reads a stream completely into a string.
ClassMethod ReadStream(stream As %Stream.Object) As %String
{
    If '$IsObject(stream) {
        Quit ""
    }
    Set out = ""
    Do stream.Rewind()
    While 'stream.AtEnd {
        Set out = out _ stream.Read(32768)
    }
    Quit out
}

/// Throws a descriptive exception.
ClassMethod Fail(message As %String)
{
    Throw ##class(%Exception.General).%New("IrisWhatsApp.Utils", 5001, "", message)
}

}