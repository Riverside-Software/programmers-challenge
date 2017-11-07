/** This is free and unencumbered software released into the public domain.
    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.  **/
/*------------------------------------------------------------------------
    File        : othello.p
    Purpose     : ABL client for PUG Challenge Othello game
    Description : 
    Author(s)   : pjudge
    Notes       : * To get this .P to compile, add $DLC/[tty|gui]/netlib/OpenEdge.Net.pl 
                    to PROPATH
                  * This is a TEMPLATE for the game. You need to fill in
                    - the values of the teamName, teamSecret and playerName 
                      variables
                    - the algorithm in the CalculateMove internal procedure                  
  ----------------------------------------------------------------------*/
routine-level on error undo, throw.

using OpenEdge.Net.HTTP.ClientBuilder.
using OpenEdge.Net.HTTP.IHttpClient.
using OpenEdge.Net.HTTP.IHttpRequest.
using OpenEdge.Net.HTTP.IHttpResponse.
using OpenEdge.Net.HTTP.RequestBuilder.
using OpenEdge.Net.URI.
using Progress.Json.ObjectModel.JsonObject.
using Progress.Lang.AppError.

/* globals */
define variable httpClient as IHttpClient no-undo.
define variable hostURI as URI no-undo.
define variable teamName as character   no-undo.
define variable teamSecret as character no-undo.
define variable playerName as character   no-undo.

/* ***************************  Main Block  *************************** */
assign httpClient = ClientBuilder:Build():Client
       hostURI    = URI:Parse('http://34.201.103.0:8080/ClientService.svc/json/':u)
       
       teamName   = ''
       teamSecret = ''
       playerName = ''
       .

run MainLoop.

catch e as Progress.Lang.Error :
    message 
    'Error executing main loop: ' e:GetMessage(1) skip
    view-as alert-box.
end catch.

/* ******************** Internal proc and function******************** */       
function GetAuthCode returns character (input authString as character):
    define variable utf8String as character no-undo.
    define variable authCode   as character no-undo.
    
    assign utf8String = codepage-convert(authString + teamSecret, 
                                         session:charset,
                                         'UTF-8':u)
           authCode   = lc(hex-encode(sha1-digest(utf8String)))
        . 
    return authCode.
end function.

procedure MainLoop:
    define variable authData as JsonObject  no-undo.
    define variable currentBoard as JsonObject  no-undo.
    define variable playerIndex as integer no-undo.
    define variable playerId as integer no-undo.
    define variable gameId as integer no-undo.
    define variable statusCode as character no-undo.
    define variable refTurn as integer no-undo.
    define variable turnRow as integer no-undo.
    define variable turnCol as integer no-undo.
    
    MAIN-LOOP:
    repeat:
        // initialize the auth object
        assign authData = new JsonObject()
               playerId = ?
               refTurn  = 0
               .
        authData:AddNull('AuthCode':u).
        authData:Add('TeamName':u,       teamName).
        authData:Add('ClientName':u,     playerName).
        authData:Add('SequenceNumber':u, 0).
        authData:Add('SessionId':u,      0).
        
        // login and get a player for the game 
        run PerformLogin (input-output authData).
        
        run CreatePlayer(input-output authData, 
                               output playerId).
        
        if playerId ne ? then
        do on error undo, throw:
            run WaitGameStart (input-output authData,
                               input        playerId,
                                     output gameId).
            if gameId eq -1 then
                undo, throw new AppError('Unable to connect to game', 0).
            
            PLAY-GAME-LOOP:
            do while true:
                run WaitNextTurn (input-output authData,
                                  input        playerId,
                                  input        refTurn,
                                        output statusCode ).
                case entry(1, statusCode, ':':u):
                    when 'GAME-OVER':u then
                        leave MAIN-LOOP.
                    when 'YOUR-TURN':u then
                    do:
                        run GetPlayerView ( input-output authData,
                                            input        playerId,
                                                  output playerIndex,
                                                  output refTurn,
                                                  output currentBoard ).
                        // this does the work of figuring out where to play next
                        run CalculateMove (input  playerIndex,
                                           input  currentBoard,
                                           output turnRow,
                                           output turnCol).
                        
                        run PerformMove (input-output authData,
                                         input        playerId,
                                         input        turnRow,
                                         input        turnCol   ).
                        
                        next PLAY-GAME-LOOP.
                    end.    // your turn
                    when 'OK':u then
                    do:
                        run GetPlayerView ( input-output authData,
                                            input        playerId,
                                                  output playerIndex,
                                                  output refTurn,
                                                  output currentBoard ).
                        next PLAY-GAME-LOOP.
                    end.
                    otherwise
                        leave MAIN-LOOP.
                end case.
            end.        // PLAY-GAME-LOOP:    
            finally:
                run LeaveGame (input-output authData,
                               input        playerId).
            end.
        end.
    end.    // MAIN-LOOP:
end procedure.        

/* Calls the endpoint */
procedure MakeRestRequest:
    define input        parameter pcMethod as character no-undo.
    define input        parameter poData as JsonObject no-undo.
    define input-output parameter poAuth as JsonObject no-undo.
    define       output parameter poResponse as JsonObject no-undo.
    
    define variable req    as IHttpRequest  no-undo.
    define variable resp   as IHttpResponse no-undo.
    define variable seqNum as integer       no-undo.
    
    assign seqNum = poAuth:GetInteger('SequenceNumber':u).
    
    // logins use 0 for session and sequence
    if not pcMethod matches '*Login':u then
        assign seqNum = seqNum + 1. 
    
    poAuth:Set('SequenceNumber':u, seqNum).
    poAuth:Set('AuthCode':u, GetAuthCode(substitute('&1:&2:&3:&4':u,
        poAuth:GetCharacter('TeamName':u), 
        poAuth:GetCharacter('ClientName':u), 
        poAuth:GetInteger('SessionId':u),
        seqNum))).
    
    if not valid-object(poData) then
        assign poData = new JsonObject().
    
    if poData:Has('Auth':u) then
        poData:Set('Auth':u, poAuth).
    else
        poData:Add('Auth':u, poAuth).
    
    assign req = RequestBuilder
                    :Post(hostURI:ToString() + pcMethod, poData)
                    :Request
           resp = httpClient:Execute(req)
           .

    if not(    resp:StatusCode eq 200     
           and type-of(resp:Entity, JsonObject) )
       then
        undo, throw new AppError('Error performing ' + pcMethod, resp:StatusCode).       
    
    assign poResponse = cast(resp:Entity, JsonObject).
end procedure .

// Logs in the client/team
procedure PerformLogin:
    define input-output parameter poAuth as JsonObject no-undo.
        
    define variable reqData   as JsonObject no-undo.
    define variable respData  as JsonObject no-undo.
    define variable challenge as character  no-undo.
    define variable statusCode as character no-undo.
    
    run MakeRestRequest('InitLogin':u,
                       ?,
                       input-output poAuth,
                             output respData).
    
    assign statusCode = 'FAIL':u
           statusCode = respData:GetCharacter('Status':u)
           no-error.
    
    if statusCode ne 'OK':u then
        undo, throw new AppError(respData:GetCharacter('Message':u), 0).
    
    assign challenge = respData:GetCharacter('Challenge':u)
           reqData   = new JsonObject()
           .
    reqData:Add('ChallengeResponse':u, GetAuthCode(GetAuthCode(challenge))).
    
    run MakeRestRequest('CompleteLogin':u,
                        reqData,
                        input-output poAuth,
                              output respData).
    // all good 
    poAuth:Set('SessionId':u, respData:GetInteger('SessionId':u)).
end procedure.  // PerformLogin    

procedure CreatePlayer:
    define input-output parameter poAuth as JsonObject no-undo.
    define output parameter piPlayerId as integer no-undo. 
    
    define variable respData as JsonObject no-undo.
    
    run MakeRestRequest('CreatePlayer':u,
                       ?,
                       input-output poAuth,
                                    output respData).
                                    
    assign piPlayerId = respData:GetInteger('PlayerId':u).
end procedure.

// Waits for a game to start
procedure WaitGameStart:
    define input-output parameter poAuth as JsonObject no-undo.
    define input        parameter piPlayerId as integer no-undo.
    define       output parameter piGameId as integer no-undo.
    
    define variable reqData as JsonObject no-undo.
    define variable respData as JsonObject no-undo.
    
    assign reqData = new JsonObject().
    reqData:Add('PlayerId':u, piPlayerId).
    
    GAME-START-LOOP:
    repeat:
        run MakeRestRequest('WaitGameStart':u,
                           reqData,
                           input-output poAuth,
                                 output respData).
        assign piGameId = respData:GetInteger('GameId':u).
        
        if piGameId gt 0 then
            leave GAME-START-LOOP.
    end.    //GAME-START-LOOP:
end procedure.

procedure WaitNextTurn:
    define input-output parameter poAuth as JsonObject no-undo.
    define input        parameter piPlayerId as integer no-undo.
    define input        parameter piRefTurn as integer no-undo.
    define       output parameter pcTurnStatus as character no-undo.
    
    define variable reqData as JsonObject no-undo.
    define variable respData as JsonObject no-undo.
    
    assign reqData = new JsonObject().
    reqData:Add('PlayerId':u, piPlayerId).
    reqData:Add('RefTurn':u, piRefTurn).
    
    TURN-LOOP:
    do while true:
        run MakeRestRequest('WaitNextTurn':u,
                           reqData,
                           input-output poAuth,
                                 output respData).
        assign pcTurnStatus = respData:GetCharacter('Status':u).
        if not pcTurnStatus eq 'OK':u then
            return.
        
        respData:writefile(session:temp-dir + 'WaitNextTurn.json', true).
        
        // it's not our turn yet
        if not respData:GetLogical('TurnComplete':u) then
            next TURN-LOOP.
        
        case true:
            when respData:GetLogical('GameFinished':u) then
            do:
                assign pcTurnStatus = 'GAME-OVER:':u
                                    + respData:GetCharacter('FinishCondition':u).
            end.
            when respData:GetLogical('YourTurn':u) then
                assign pcTurnStatus = 'YOUR-TURN':u.
        end case.
        // all done here
        leave TURN-LOOP.
    end.        //TURN-LOOP:
end procedure.

procedure GetPlayerView:
    define input-output parameter poAuth as JsonObject no-undo.
    define input        parameter piPlayerId as integer no-undo.
    define       output parameter piPlayerIndex as integer no-undo.
    define       output parameter piRefTurn as integer no-undo.
    define       output parameter poBoardState as JsonObject no-undo.
    
    define variable reqData as JsonObject no-undo.
    define variable respData as JsonObject no-undo.
    
    assign reqData = new JsonObject().
    reqData:Add('PlayerId':u, piPlayerId).
    
    run MakeRestRequest('GetPlayerView':u,
                       reqData,
                       input-output poAuth,
                             output respData).
    
    assign piRefTurn     = respData:GetInteger('Turn':u)
           poBoardState  = respData:GetJsonObject('Map':u)
           piPlayerIndex = respData:GetInteger('Index':u)
           .
end procedure.    

procedure CalculateMove:
    define input  parameter piPlayerIndex as integer no-undo.
    define input  parameter poBoardState as JsonObject no-undo.
    define output parameter piRow as integer no-undo.
    define output parameter piCol as integer no-undo.
    
    // YOUR BRAINZ HERE
    
    /* The ROW and COLUMN values returned here are expected to be 1-based
       IOW ABL format (not 0-based). 
       
       returning 0 anmd 0 indicate 'PASS'   */
end procedure.
    
procedure PerformMove: 
    define input-output parameter poAuth as JsonObject no-undo.
    define input        parameter piPlayerId as integer no-undo.
    define input        parameter piRow as integer no-undo.
    define input        parameter piCol as integer no-undo.

    define variable reqData as JsonObject no-undo.
    define variable turnPos as JsonObject no-undo.
    define variable respData as JsonObject no-undo.
    
    assign reqData = new JsonObject()
           turnPos = new JsonObject()
           .
    reqData:Add('PlayerId':u, piPlayerId).
    
    reqData:Add('Turn':u, turnPos).
    // server is 0-based
    turnPos:Add('Row':u, piRow - 1).
    turnPos:Add('Col':u, piCol - 1).
    
    reqData:Add('Pass':u, (piRow eq 0 and piCol eq 0)).
    
    run MakeRestRequest('PerformMove':u,
                        reqData,
                        input-output poAuth,
                              output respData).
end procedure.

procedure LeaveGame:   
    define input-output parameter poAuth as JsonObject no-undo.
    define input        parameter piPlayerId as integer no-undo.

    define variable reqData as JsonObject no-undo.
    define variable respData as JsonObject no-undo.
    
    assign reqData = new JsonObject().
    reqData:Add('PlayerId':u, piPlayerId).
    
    run MakeRestRequest('LeaveGame':u,
                       reqData,
                       input-output poAuth,
                             output respData).
end procedure.
