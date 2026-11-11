Imports System.Threading

''' <summary>
''' Stand-in for a legacy VB.NET business DLL. Bodies have no APM / OTel calls —
''' Contoso.Observability.TraceAttribute weaves spans at build time (Fody).
''' Root namespace: Contoso.Shipments.LegacyVb
''' </summary>
Public Class LegacyShipmentService
    Public Function NormalizeTrackingId(trackingId As String) As String
        If String.IsNullOrWhiteSpace(trackingId) Then
            Return "UNKNOWN"
        End If
        Return trackingId.Trim().ToUpperInvariant()
    End Function

    Public Function ClassifyLane(lane As String) As String
        If String.IsNullOrWhiteSpace(lane) Then
            Return "DEFAULT"
        End If
        If lane.IndexOf("SLOW", StringComparison.OrdinalIgnoreCase) >= 0 Then
            Return "DEFERRED"
        End If
        Return "STANDARD"
    End Function

    ''' <summary>
    ''' Demo entry point shown under POST Checkout as LegacyShipmentService.EnrichQuoteNote.
    ''' </summary>
    Public Function EnrichQuoteNote(trackingId As String, lane As String, weightKg As Integer) As String
        Dim id = NormalizeTrackingId(trackingId)
        Dim classification = ClassifyLane(lane)
        ' Small delay so the span is visible under Windows timer resolution in the lab.
        Thread.Sleep(20)
        Return String.Format("VB:{0}:{1}:{2}kg", id, classification, weightKg)
    End Function
End Class
