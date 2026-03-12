-module(server).
-export([start/1,stop/1]).

-record(server_st,{
   channels, % Client Pids to connect channels to clients
   nicks
}).

-record(channel_st, {
    users
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
        nicks = #{}
    }.

% Handles join on server level
% Calls on handle_channel when Pid is created
handle(St, {join, Channel, ClientPid}) ->
    case lists:keyfind(Channel, 1, St#server_st.channels) of
        false ->
            ChannelPid = genserver:start(list_to_atom(Channel), #channel_st{users = []}, fun handle_channel/2),
            Reply = genserver:request(ChannelPid, {join, ClientPid}),
            {reply, Reply, St#server_st{channels = [{Channel, ChannelPid} | St#server_st.channels]}};
        {Channel, ChannelPid} ->
            genserver:request(ChannelPid, {join, ClientPid}),
            {reply, ok, St}
    end;

% To return all channels associated with a server
handle(St, active_channels) ->
    {reply, St#server_st.channels, St}.

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

% Sends the message to all users in the channel
handle_channel(St, {message_send, Channel, Msg, Nick, ClientPid}) ->
    CurrentUsers = St#channel_st.users,
    TargetUsers = lists:filter(fun(Pid) -> Pid =/= ClientPid end, CurrentUsers),
    lists:foreach(fun(Pid) -> 
        spawn(fun() -> genserver:request(Pid, {message_receive, Channel, Nick, Msg}) end)
    end, TargetUsers),
    {reply, ok, St}.


    


%  Distinction assignment

% handle(St, {nick, NewNick, ClientPid}) ->
%     CurrentNicks = maps:get(NewNick, St#server_st.nicks, []),
%     NewNicks = #{},
%     if
%         length(CurrentNicks) >= 1 ->
%             {reply, {error, nick_taken, "That nick is already in use"}, St};

%         true ->
%             NewNicks = maps:put(NewNick, [ClientPid | CurrentNicks], St#server_st.nicks)
%     end,
%     {reply, ok, St#server_st{nicks = NewNicks}}.
    
    