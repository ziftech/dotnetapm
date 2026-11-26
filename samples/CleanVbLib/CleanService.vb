Imports System.Threading.Tasks

Public Class CleanService
    Public Function Ping(name As String) As String
        Return "pong:" & If(name, String.Empty)
    End Function

    Public Async Function PingAsync(name As String) As Task(Of String)
        Await Task.Delay(1).ConfigureAwait(False)
        Return "pong-async:" & If(name, String.Empty)
    End Function

    Public Sub Boom()
        Throw New InvalidOperationException("clean-boom")
    End Sub

    Public Property Value As Integer

    Public Sub New()
        Value = 1
    End Sub
End Class
