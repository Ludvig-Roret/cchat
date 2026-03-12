-module(server).
-export([start/1,stop/1]).

-record(server_st,{
   channels,    % List of tuples with Channel name and channel Pid
   nicks        % List of all nicks associated with the server
}).

-record(channel_st, {
    users       % List of the users connected to the channel
}).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    % TODO Implement function
    % - Spawn a new process which waits for a message, handles it, then loops infinitely
    % - Register this process to ServerAtom
    % - Return the process ID
    genserver:start(ServerAtom, initial_state(), fun handle/2).

% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    % TODO Implement function
    % Return ok

    Channels = genserver:request(ServerAtom, active_channels),
    lists:foreach(fun({_, Pid}) -> genserver:stop(Pid) end, Channels),
    genserver:stop(ServerAtom),
    ok.

initial_state() ->
    #server_st{
        channels = [],
        nicks = []
    }.

% Return all channels associated with a server
handle(St, active_channels) ->
    {reply, St#server_st.channels, St};

% Handles join on server level
handle(St, {join, Channel, ClientPid, Nick}) ->

    % Check if the users nick is in the nicks lists, add it if not
    NewNicks = case lists:member(Nick, St#server_st.nicks) of
        true -> St#server_st.nicks;
        false -> [Nick | St#server_st.nicks]
    end,

    % Check if the Channel name is in the channel list,
    % if not -> Create the channel Pid and add it to the list
    % otherwise -> request to join on channel level
    case lists:keyfind(Channel, 1, St#server_st.channels) of
        false ->
            ChannelPid = genserver:start(list_to_atom(Channel), #channel_st{users = []}, fun handle_channel/2),
            Reply = genserver:request(ChannelPid, {join, ClientPid}),
            {reply, Reply, St#server_st{channels = [{Channel, ChannelPid} | St#server_st.channels], nicks = NewNicks}};
        {Channel, ChannelPid} ->
            genserver:request(ChannelPid, {join, ClientPid}),
            {reply, ok, St#server_st{nicks = NewNicks}}
    end;

%  Distinction assignment

% Check if the new nick is in use, 
% if yes -> error
% otherwise -> remove previous nick and add the new one
handle(St, {nick, NewNick, CurrentNick}) ->
    AllNicks = St#server_st.nicks,
    case lists:member(NewNick, AllNicks) of
        true ->
            {reply, {error, nick_taken, "Nick already taken"}, St};
        false ->
            UpdatedNicks = [NewNick | lists:delete(CurrentNick, AllNicks)],
            {reply, ok, St#server_st{nicks = UpdatedNicks}}
    end.

% Handles for the channel record

% Adds user to the channels user list
handle_channel(St, {join, ClientPid}) ->
    CurrentUsers = St#channel_st.users,
    NewUsers = [ClientPid | CurrentUsers],
    {reply, ok, St#channel_st{users = NewUsers}};

% Removes user from the list och users for a channel
handle_channel(St, {leave, ClientPid}) -> 
    CurrentUsers = St#channel_st.users,
    NewUsers = lists:filter(fun(Pid) -> Pid =/= ClientPid end, CurrentUsers),
    {reply, ok, St#channel_st{users = NewUsers}};

% Sends the message to all users in the channel by
% spawning a new process for every user that sends a "message_receive" message
% to all clientPids but itself 
handle_channel(St, {message_send, Channel, Msg, Nick, ClientPid}) ->
    CurrentUsers = St#channel_st.users,
    TargetUsers = lists:filter(fun(Pid) -> Pid =/= ClientPid end, CurrentUsers),
    lists:foreach(fun(Pid) -> 
        spawn(fun() -> genserver:request(Pid, {message_receive, Channel, Nick, Msg}) end)
    end, TargetUsers),
    {reply, ok, St}.
    