VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsOWA"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
''
'WebDav code to comunicete with Exchange server
'
'@author Carlos B
'@version 1.0
'@date 26/11/2005

Option Explicit

''
'Translations between XML tags of OWA and valid headers of a POP3 message
'@see initArrays
Private dicTags         As Dictionary
Private objDOMFolders   As DOMDocument

Public intMsgCount As Integer

''
'Get the URL of one inbox message
'
'@param intMsg  Position of the message in the inbox folder
Private Function GetURL(ByVal intMsg As Integer) As String
    GetURL = objDOMInbox.childNodes(1).childNodes(intMsg - 1).selectSingleNode("a:propstat/a:prop/a:href").Text
End Function


''
'Get all files asociated to a message.
'
'@param strUrl  Url of the .EML file
'@return
Public Function GetAttachmentsList(ByVal strUrl As String) As IXMLDOMNodeList
Dim oXMLHTTP As XMLHTTP

Set oXMLHTTP = New XMLHTTP
With oXMLHTTP
    .open "X-MS-ENUMATTS", strUrl, False, strUser, strPassWord
    .setRequestHeader "Depth", "1"
    .setRequestHeader "Content-type", "xml"
    .Send
    If .Status = 207 Then
        #If DEBUG_MODE = 1 Then
            .responseXML.save "c:\ATTS2.xml"
        #End If
        Set GetAttachmentsList = .responseXML.selectNodes("a:multistatus/a:response")
    End If
End With
Set oXMLHTTP = Nothing
End Function


''
'Retrieve the attachment of a message.
'
'@param strUrl  Url of the .EML file
'@return Binary content encoded in Base64
Public Function GetAttachment(ByVal strUrl As String) As String
Dim oXMLHTTP    As XMLHTTP
Dim objMIME     As Base64
Set objMIME = New Base64
Set oXMLHTTP = New XMLHTTP
    oXMLHTTP.open "GET", strUrl, False, strUser, strPassWord
    oXMLHTTP.Send
    GetAttachment = objMIME.EncodeArr(oXMLHTTP.responseBody)
Set objMIME = Nothing
Set oXMLHTTP = Nothing
End Function

''
'Delete a message
'
'@param intMsg  Position of the message in the inbox folder
Public Function Delete(ByVal intMsg As Integer) As Boolean
On Error GoTo GestionErrores
Dim oXMLHTTP    As XMLHTTP
    
    Set oXMLHTTP = New XMLHTTP
    With oXMLHTTP
        .open "DELETE", GetURL(intMsg), False, strUser, strPassWord
        .setRequestHeader "Depth", "infinity"
        .Send
    '    Debug.Print .Status
    End With
    Delete = True

Set oXMLHTTP = Nothing
Exit Function
GestionErrores:
    Delete = False
End Function

''
'Load an OWA mesagge into a XML object.
'
'@param strUrl Url of the .EML file
'@see objDOMMsg
Public Sub LoadMsg(ByVal strUrl As String)
Dim oXMLHTTP As XMLHTTP
' Create an instance of the xmlHTTP object
Set oXMLHTTP = CreateObject("microsoft.xmlhttp")
With oXMLHTTP
    ' Open a request to a particular url
    .open "PROPFIND", strUrl, False, strUser, strPassWord
    ' Set the header type
    .setRequestHeader "Content-type:", "text/xml"
    .setRequestHeader "Depth", "1"
    ' Send the request
    .Send
    While .readyState <> 4
        Sleep 10
        DoEvents
        'Debug.Assert oXMLHTTP.readyState <> 3
    Wend
    If (.Status >= 200 And .Status < 300) Then
        Set objDOMMsg = .responseXML
        #If DEBUG_MODE = 1 Then
            objDOMMsg.save "C:\mensaje.xml"
        #End If
    Else
        Err.Raise 51
    End If
End With
Set oXMLHTTP = Nothing
End Sub


Private Function GetAttachmentName(ByVal strUrl As String) As String
Dim oXMLHTTP As XMLHTTP
Set oXMLHTTP = New XMLHTTP
With oXMLHTTP
    .open "PROPFIND", strUrl, False, strUser, strPassWord
    .Send
    'GetAttachment = oXMLHTTP.responseText
    If .Status = 207 Then
        #If DEBUG_MODE = 1 Then
            objDOMInbox.save "c:\ATT.xml"
        #End If
        GetAttachmentName = .responseXML.selectSingleNode("a:multistatus/a:response/a:propstat/a:prop/a:displayname").Text
    End If
End With
Set oXMLHTTP = Nothing
End Function

''
'Get the list of al messages in the inbox folder.
'
'@return Reply to e-mail client
Public Function GetMsgList() As Boolean
On Error GoTo GestionErrores

    Dim strUrl As String
    Dim oXMLHTTP As XMLHTTP
    strUrl = objDOMFolders.selectSingleNode(XMLPATH & "d:inbox").Text & "/"
    ' Create an instance of the xmlHTTP object
    Set oXMLHTTP = CreateObject("microsoft.xmlhttp")
    With oXMLHTTP
        ' Open a request to a particular url
        .open "SEARCH", strUrl, False, strUser, strPassWord
        ' Set the header type - we want XML
        .setRequestHeader "Content-type:", "text/xml"
        .setRequestHeader "Depth", "1"
        ' Send the request
        Sleep 100
        Call .Send("<?xml version='1.0' ?>" & _
                    "<a:searchrequest xmlns:a='DAV:'><a:sql>" & _
                     "SELECT" & _
                     " ""DAV:href""" & _
                     ",""urn:schemas:httpmail:subject""" & _
                     ",""DAV:id""" & _
                     ",""DAV:ishidden""" & _
                     " FROM scope('shallow traversal of """ & strUrl & """')" & _
                    " WHERE ""DAV:ishidden""=False" & _
                    " AND ""DAV:isfolder""=False" & _
                    "</a:sql></a:searchrequest>")

        While .readyState <> 4
            Sleep 10
            DoEvents
            'Debug.Assert oXMLHTTP.readyState <> 3
        Wend
        Set objDOMInbox = .responseXML
        intMsgCount = objDOMInbox.childNodes(1).childNodes.Length
        #If DEBUG_MODE = 1 Then
            objDOMInbox.save "C:\listado.XML"
        #End If
    End With
    GetMsgList = True
Exit Function
GestionErrores:
    Debug.Assert False
    Debug.Print Err.Description
    GetMsgList = False
End Function
Public Function GetFoldersURL() As Boolean

On Error GoTo ErrHandler
Dim query As String
Dim strUrl As String
Dim oXMLHTTP    As XMLHTTP

query = "<?xml version='1.0'?>"
query = query + "<a:propfind xmlns:a='DAV:'>"
query = query + "<a:prop xmlns:m='urn:schemas:httpmail:'>"
query = query + "<m:sendmsg/>"
query = query + "<m:inbox/>"
query = query + "</a:prop>"
query = query + "</a:propfind>"

Set oXMLHTTP = New XMLHTTP
strUrl = strExchSvrName & "/exchange/" & strUser & "/"
With oXMLHTTP
    .open "PROPFIND", strUrl, False, strUser, strPassWord
    .setRequestHeader "Content-Type", "text/xml"
    .setRequestHeader "Depth", "0"
    
    .Send query
    
    ' process the result
    If (.Status >= 200 And .Status < 300) Then
       Set objDOMFolders = .responseXML
       GetFoldersURL = True
    Else
       GetFoldersURL = False
    End If
End With
Set oXMLHTTP = Nothing
Exit Function
ErrHandler:
    GetFoldersURL = False
End Function


''
'Get the date of a message, converting OWA format in a standar date (rfc1939).
'
'@param strDate Date in OWA format
'@return Standar date (rfc1939)
Private Function GetPOPDate(ByVal strDate As String) As String
Dim vDate As Variant
Dim vDays(1 To 7) As String
Dim vMonths(1 To 12) As String
Dim strReturn As String
vDays(1) = "Mon"
vDays(2) = "Tue"
vDays(3) = "Wed"
vDays(4) = "Thu"
vDays(5) = "Fri"
vDays(6) = "Sat"
vDays(7) = "Sun"

vMonths(1) = "Jan"
vMonths(2) = "Feb"
vMonths(3) = "Mar"
vMonths(4) = "Apr"
vMonths(5) = "May"
vMonths(6) = "Jun"
vMonths(7) = "Jul"
vMonths(8) = "Aug"
vMonths(9) = "Sep"
vMonths(10) = "Oct"
vMonths(11) = "Nov"
vMonths(12) = "Dec"
    vDate = Split(strDate, "T")
    strReturn = vDays(DatePart("w", vDate(0)))
    strReturn = strReturn & ", " & DatePart("d", vDate(0))
    strReturn = strReturn & " " & vMonths(DatePart("m", vDate(0)))
    strReturn = strReturn & " " & DatePart("yyyy", vDate(0))
    GetPOPDate = strReturn & " " & FormatDateTime(Left(vDate(1), 8), vbLongTime) & " UT"
End Function

''
'Get the headers of a message.
'
'@return Header of the mail
Public Function getMsgHeader() As String
Dim strDataToSend   As String
Dim vKeys           As Variant
Dim Key             As Variant
Dim strValue        As String
Dim intPos1         As Integer
Dim intPos2         As Integer
Dim strEmail        As String
Dim strName         As String
Dim strReturn       As String

vKeys = dicTags.Keys
For Each Key In vKeys
    If Not objDOMMsg.selectSingleNode(XMLPATH & dicTags.Item(Key)) Is Nothing Then
        strValue = objDOMMsg.selectSingleNode(XMLPATH & dicTags.Item(Key)).Text
        Select Case Key
        Case "Importance"
            Select Case strValue
            Case 0
                strDataToSend = strDataToSend & "Importance: Low" & vbCrLf
                strDataToSend = strDataToSend & "X-MSMail-Priority: Low" & vbCrLf
                strDataToSend = strDataToSend & "X-Priority: 5" & vbCrLf
'Default values are omited
'            Case 1
'                strDataToSend = strDataToSend & "Importance: Normal" & vbCrLf
'                strDataToSend = strDataToSend & "X-MSMail-Priority: Normal" & vbCrLf
'                strDataToSend = strDataToSend & "X-Priority: 3" & vbCrLf
            Case 2
                strDataToSend = strDataToSend & "Importance: High" & vbCrLf
                strDataToSend = strDataToSend & "X-MSMail-Priority: High" & vbCrLf
                strDataToSend = strDataToSend & "X-Priority: 1" & vbCrLf
            End Select
        Case "Date"
            strValue = GetPOPDate(strValue)
            strDataToSend = strDataToSend & Key & ": " & strValue & vbCrLf
        Case "To", "Cc", "Bcc", "From", "Disposition-Notification-To"
            strReturn = Empty
            Do
                strValue = strValue & "  "
                intPos1 = InStr(strValue, ">")
                If intPos1 > 0 Then
                    intPos2 = InStr(strValue, "<")
                    strName = Trim(Mid(strValue, 1, intPos2 - 1))
                    strEmail = Mid(strValue, intPos2, intPos1 - intPos2 + 1)
                    If Left(strName, 1) <> """" Then
                        strName = """" & strName & """"
                    End If
                    strReturn = strReturn & strName & " " & strEmail & ", "
                    strValue = Mid(strValue, intPos1 + 2)
                End If
            Loop While intPos1 <> 0
            strDataToSend = strDataToSend & Key & ": " & Mid(strReturn, 1, Len(strReturn) - 2) & vbCrLf
        Case Else
            strDataToSend = strDataToSend & Key & ": " & strValue & vbCrLf
        End Select
    ElseIf Key = "Content-Transfer-Encoding" Then
        strDataToSend = strDataToSend & "Content-Transfer-Encoding: 8bit " & vbCrLf
    End If
Next
getMsgHeader = strDataToSend
End Function

''
'Init a public dictionary with the trlanslation of XML tags of OWA
' and valid headers of a POP3 message
'@see dicTags
Private Sub initArrays()
    Set dicTags = New Dictionary
    dicTags.Add "Date", "e:date"
    dicTags.Add "From", "e:from"
    dicTags.Add "To", "e:to"
    dicTags.Add "Cc", "e:cc"
    dicTags.Add "Bcc", "e:bcc"
    dicTags.Add "Subject", "e:subject"
    dicTags.Add "Importance", "e:importance"
    'dicTags.Add "Received", "d:received"
    'dicTags.Add "Content-Type", "d:content-type"
    dicTags.Add "Content-Transfer-Encoding", "d:content-transfer-encoding"
    dicTags.Add "MIME-Version", "d:mime-version"
    dicTags.Add "Message-ID", "d:message-id"
    dicTags.Add "X-Mailer", "d:x-mailer"
    dicTags.Add "Disposition-Notification-To", "d:disposition-notification-to"
    dicTags.Add "Content-Class", "a:contentclass"

End Sub


Public Function SendMail(ByVal strMailData As String) As Boolean

Dim strSubURL
strSubURL = objDOMFolders.selectSingleNode(XMLPATH & "d:sendmsg").Text
'         To use MSXML 4.0 use the followinf DIM/SET statements
         Dim xmlReq As XMLHTTP
         Set xmlReq = New XMLHTTP

         On Error GoTo ErrHandler

          'Create the DAV PUT request.

         xmlReq.open "PUT", strSubURL, False, strUser, strPassWord
         If strMailData <> "" Then
            xmlReq.setRequestHeader "Content-Type", "message/rfc821"
            If Not bSaveinsent Then
                xmlReq.setRequestHeader "Saveinsent", "f"
            End If
            xmlReq.Send strMailData
         
         End If

         'Process the results.
         If (xmlReq.Status >= 200 And xmlReq.Status < 300) Then
            SendMail = True
         Else
            SendMail = False
         End If
ErrExit:
      Set xmlReq = Nothing
      Exit Function
ErrHandler:
    Debug.Print Err.Description
      SendMail = False
End Function

Private Sub Class_Initialize()
initArrays
End Sub