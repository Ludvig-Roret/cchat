-module(client).
-export([handle/2, initial_state/3]).

% This record defines the structure of the state of a client.
% Add whatever other fields you need.
-record(client_st, {
    gui, % atom of the GUI process
    nick, % nick/username of the client
    server, % atom of the chat server
    channels % channels entered
}).

% Return an initial state record. This is called from GUI.
% Do not change the signature of this function.
initial_state(Nick, GUIAtom, ServerAtom) ->
    #client_st{
        gui = GUIAtom,
        nick = Nick,
        server = ServerAtom,
        channels = []
    }.

% handle/2 handles each kind of request from GUI
% Parameters:
%   - the current state of the client (St)
%   - request data from GUI
% Must return a tuple {reply, Data, NewState}, where:
%   - Data is what is sent to GUI, either the atom `ok` or a tuple {error, Atom, "Error message"}
%   - NewState is the updated state of the client

% Join channel
handle(St, {join, Channel}) ->
    % TODO: Implement this function
    case whereis(St#client_st.server) of
        undefined ->
            {reply, {error, server_not_reached, "Server doesn't exist"}, St}; % If the server doesnt exist, error
        _ -> 
            case lists:member(Channel, St#client_st.channels) of
                true -> {reply, {error, user_already_joined, "User already joined"}, St}; % If user is already in the channels user list
                false ->
                    % Try to join on the serverside, if it works add Channel to the clients channel list,
                    % otherwise throw error
                    try genserver:request(St#client_st.server, {join, Channel, self(), St#client_st.nick}) of
                        ok ->
                            NewState = St#client_st{channels = [Channel | St#client_st.channels]}, 
                            {reply, ok, NewState}
                    catch
                        throw : timeout_error -> {reply, {error, server_not_reached, "Server not responding"}, St}
                    end
            end
    end;

% Leave channel
handle(St, {leave, Channel}) ->
    % TODO: Implement this function

    % Check if the channel is in the clients channel list, if yes leave on channel level
    % otherwise reply error
    case lists:member(Channel, St#client_st.channels) of
        true ->            
            genserver:request(list_to_atom(Channel), {leave, self()}) ,
            NewChannels = St#client_st.channels,

            NewState = St#client_st{channels = lists:filter(fun(Ch) -> Ch =/= Channel end, NewChannels)}, 
            {reply, ok, NewState};
        false ->
            {reply, {error, user_not_joined, "User not joined in channel"}, St}
    end;

% Sending message (from GUI, to channel)
handle(St, {message_send, Channel, Msg}) ->
    % TODO: Implement this function

    % Check if the channel exists: if not -> error, 
    % otherwise check if client is joined in the given channel: yes -> send message on the channel level,
    % otherwise -> error
    case whereis(list_to_atom(Channel)) of
        undefined ->
             {reply, {error, server_not_reached, "Channel isn't created"}, St};
        _ ->
            case lists:member(Channel, St#client_st.channels) of
                true ->
                    try genserver:request(list_to_atom(Channel), {message_send, Channel, Msg, St#client_st.nick, self()}) of
                        ok -> {reply, ok, St}
                    catch
                        throw : timeout_error -> {reply, {error, server_not_reached, "Server not responding"}, St}
                    end;
                false ->
                    {reply, {error, user_not_joined, "User not joined in channel"}, St}
            end
    end;

% This case is only relevant for the distinction assignment!
% Change nick (no check, local only)
handle(St, {nick, NewNick}) ->

    % Try change nick on the server side, if it returns an error -> error
    % otherwise -> Change nick.
    case genserver:request(St#client_st.server, {nick, NewNick, St#client_st.nick}) of
        ok ->
            {reply, ok, St#client_st{nick = NewNick}};
        _ ->
            {reply, {error, nick_taken, "Nick already taken"}, St}
    end;

% ---------------------------------------------------------------------------
% The cases below do not need to be changed...
% But you should understand how they work!

% Get current nick
handle(St, whoami) ->
    {reply, St#client_st.nick, St} ;

% Incoming message (from channel, to GUI)
handle(St = #client_st{gui = GUI}, {message_receive, Channel, Nick, Msg}) ->
    gen_server:call(GUI, {message_receive, Channel, Nick++"> "++Msg}),
    {reply, ok, St} ;

% Quit client via GUI
handle(St, quit) ->
    % Any cleanup should happen here, but this is optional
    {reply, ok, St} ;

% Catch-all for any unhandled requests
handle(St, Data) ->
    {reply, {error, not_implemented, "Client does not handle this command"}, St} .
