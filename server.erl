-module(server).
-export([start/1,stop/1]).

-record(server_st,{
   channels % Client Pids to connect channels to clients
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
    genserver:stop(ServerAtom),
    ok.

initial_state() ->
    #server_st{
        channels = #{}
    }.

handle(St, {join, Channel, ClientPid, Gui}) ->
    CurrentPids = maps:get(Channel, St#server_st.channels, []),
    NewPids = maps:put(Channel, [{ClientPid , Gui}| CurrentPids], St#server_st.channels),
    {reply, ok, St#server_st{channels = NewPids}};

handle(St, {leave, Channel, ClientPid}) -> 
    CurrentPids = maps:get(Channel, St#server_st.channels, []),
    NewList = lists:filter(fun({Pid, _}) -> Pid =/= ClientPid end, CurrentPids),
    NewPids = maps:put(Channel, NewList, St#server_st.channels),
    {reply, ok, St#server_st{channels = NewPids}};


handle(St, {message_send, Channel, Msg, Nick, ClientPid}) ->
    CurrentPids = maps:get(Channel, St#server_st.channels, []),
    TargetPids = lists:filter(fun({Pid, _}) -> Pid =/= ClientPid end, CurrentPids),
    lists:foreach(fun({Pid, _}) -> 
        spawn(fun() -> genserver:request(Pid, {message_receive, Channel, Nick, Msg}) end)
    end, TargetPids),
    {reply, ok, St}.