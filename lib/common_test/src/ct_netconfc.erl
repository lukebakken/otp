%%----------------------------------------------------------------------
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2012-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%
%%----------------------------------------------------------------------
%% File: ct_netconfc.erl
%%
%% Description:
%%    This file contains the Netconf client interface
%%
%% Netconf servers can be configured by adding the following statement
%% to a configuration file:
%%
%% {server_id(), [option()]}.
%%
%% The server_id() or an associated ct:target_name() shall then be
%% used in calls to open/2 connect/2.
%%
%% If no configuration exists for a server, use open/1 and connect/1.
%%
%% == Logging ==
%%
%% The netconf server uses the `error_logger' for logging of netconf
%% traffic. A special purpose error handler is implemented in
%% `ct_conn_log_h'. To use this error handler, add the `cth_conn_log'
%% hook in your test suite, e.g.
%%
%% suite() ->
%%     [{ct_hooks, [{cth_conn_log, [{ct:conn_log_mod(),ct:conn_log_options()}]}]}].
%%
%% For example:
%%
%% suite() ->
%%     [{ct_hooks,
%%         [{cth_conn_log,[{ct_netconfc,[{log_type,pretty},
%%                                       {hosts,[my_configured_server]}]}]}
%%
%% == Notifications ==
%%
%% The netconf client is also compliant with RFC5277 NETCONF Event
%% Notifications, which defines a mechanism for an asynchronous
%% message notification delivery service for the netconf protocol.
%% Functions supporting this are create_subscription/3
%% get_event_streams/3.
%%
%%----------------------------------------------------------------------
-module(ct_netconfc).
-moduledoc """
NETCONF client module.

NETCONF client module compliant with RFC 6241, NETCONF Configuration Protocol,
and RFC 6242, Using the NETCONF Configuration Protocol over Secure SHell (SSH),
and with support for RFC 5277, NETCONF Event Notifications.

[](){: #Connecting }

_Connecting to a NETCONF server_

Call [`connect/1,2`](`connect/1`) to establish a connection to a server, then
pass the returned handle to [`session/1-3`](`session/1`) to establish a NETCONF
session on a new SSH channel. Each call to [`session/1-3`](`session/1`)
establishes a new session on the same connection, and results in a hello message
to the server.

Alternately, [`open/1,2`](`open/1`) can be used to establish a single session on
a dedicated connection. (Or, equivalently, [`only_open/1,2`](`only_open/1`)
followed by [`hello/1-3`](`hello/1`).)

Connect/session options can be specified in a configuration file with entries
like the following.

```erlang
{server_id(), [option()]}.
```

The `t:server_id/0` or an associated `t:ct:target_name/0` can then be passed to
the aforementioned functions to use the referenced configuration.

[](){: #Signaling }

_Signaling_

Protocol operations in the NETCONF protocol are realized as remote procedure
calls (RPCs) from client to server and a corresponding reply from server to
client. RPCs are sent using like-named functions (eg.
[`edit_config/3-5`](`edit_config/3`) to send an edit-config RPC), with the
server reply as return value. There are functions for each RPC defined in RFC
6241 and the create-subscription RPC from RFC 5277, all of which are wrappers on
[`send_rpc/2,3`](`send_rpc/2`), that can be used to send an arbitrary RPC not
defined in RFC 6241 or RFC 5277.

All of the signaling functions have one variant with a `Timeout` argument and
one without, corresponding to an infinite timeout. The latter is inappropriate
in most cases since a non-response by the server or a missing message-id causes
the call to hang indefinitely.

[](){: #Logging }

_Logging_

The NETCONF server uses `error_logger` for logging of NETCONF traffic. A special
purpose error handler is implemented in `ct_conn_log_h`. To use this error
handler, add the `cth_conn_log` hook in the test suite, for example:

```erlang
suite() ->
    [{ct_hooks, [{cth_conn_log, [{ct:conn_log_mod(), ct:conn_log_options()}]}]}].
```

`conn_log_mod()` is the name of the `Common Test` module implementing the
connection protocol, for example, `ct_netconfc`.

Hook option `log_type` specifies the type of logging:

- **`raw`** - The sent and received NETCONF data is logged to a separate text
  file "as is" without any formatting. A link to the file is added to the test
  case HTML log.

- **`pretty`** - The sent and received NETCONF data is logged to a separate text
  file with XML data nicely indented. A link to the file is added to the test
  case HTML log.

- **`html (default)`** - The sent and received NETCONF traffic is pretty printed
  directly in the test case HTML log.

- **`silent`** - NETCONF traffic is not logged.

By default, all NETCONF traffic is logged in one single log file. However,
different connections can be logged in separate files. To do this, use hook
option `hosts` and list the names of the servers/connections to be used in the
suite. The connections must be named for this to work, that is, they must be
opened with `open/2`.

Option `hosts` has no effect if `log_type` is set to `html` or `silent`.

The hook options can also be specified in a configuration file with
configuration variable `ct_conn_log`:

```erlang
{ct_conn_log,[{ct:conn_log_mod(), ct:conn_log_options()}]}.
```

For example:

```erlang
{ct_conn_log,[{ct_netconfc,[{log_type,pretty},
                            {hosts,[ct:key_or_name()]}]}]}
```

> #### Note {: .info }
>
> Hook options specified in a configuration file overwrite the hard-coded hook
> options in the test suite.

_Logging Example 1:_

[](){: #Logging_example_1 }

The following `ct_hooks` statement causes pretty printing of NETCONF traffic to
separate logs for the connections named `nc_server1` and `nc_server2`. Any other
connections are logged to default NETCONF log.

```erlang
suite() ->
   [{ct_hooks, [{cth_conn_log, [{ct_netconfc,[{log_type,pretty}},
                                              {hosts,[nc_server1,nc_server2]}]}
                               ]}]}].
```

Connections must be opened as follows:

```erlang
open(nc_server1,[...]),
open(nc_server2,[...]).
```

_Logging Example 2:_

[](){: #Logging_example_2 }

The following configuration file causes raw logging of all NETCONF traffic in to
one single text file:

```erlang
{ct_conn_log,[{ct_netconfc,[{log_type,raw}]}]}.
```

The `ct_hooks` statement must look as follows:

```erlang
suite() ->
    [{ct_hooks, [{cth_conn_log, []}]}].
```

The same `ct_hooks` statement without the configuration file would cause HTML
logging of all NETCONF connections in to the test case HTML log.
""".
-moduledoc(#{since => "OTP R15B02"}).

-dialyzer(no_improper_lists).

-include("ct_netconfc.hrl").
-include("ct_util.hrl").
-include_lib("xmerl/include/xmerl.hrl").

%%----------------------------------------------------------------------
%% External exports
%%----------------------------------------------------------------------
-export([connect/1,
         connect/2,
         disconnect/1,
         session/1,
         session/2,
         session/3,
         open/1,
	 open/2,
	 only_open/1,
	 only_open/2,
	 hello/1,
	 hello/2,
	 hello/3,
	 close_session/1,
	 close_session/2,
	 kill_session/2,
	 kill_session/3,
	 send/2,
	 send/3,
	 send_rpc/2,
	 send_rpc/3,
	 lock/2,
	 lock/3,
	 unlock/2,
	 unlock/3,
	 get/2,
	 get/3,
	 get_config/3,
	 get_config/4,
	 edit_config/3,
	 edit_config/4,
	 edit_config/5,
	 delete_config/2,
	 delete_config/3,
	 copy_config/3,
	 copy_config/4,
	 action/2,
	 action/3,
	 create_subscription/2,
	 create_subscription/3,
	 get_event_streams/1,
	 get_event_streams/2,
	 get_event_streams/3,
	 get_capabilities/1,
	 get_capabilities/2,
	 get_session_id/1,
	 get_session_id/2]).

%% historic, no longer documented
-export([create_subscription/1,
	 create_subscription/4,
	 create_subscription/5,
	 create_subscription/6]).

%%----------------------------------------------------------------------
%% Exported types
%%----------------------------------------------------------------------
-export_type([client/0,
              handle/0,
              notification/0]).

%%----------------------------------------------------------------------
%% Internal exports
%%----------------------------------------------------------------------
%% ct_gen_conn callbacks
-export([init/3,
	 handle_msg/3,
	 handle_msg/2,
	 terminate/2,
	 close/1]).

%% ct_conn_log callback
-export([format_data/2]).

%%----------------------------------------------------------------------
%% Internal defines
%%----------------------------------------------------------------------
-define(APPLICATION,?MODULE).
-define(DEFAULT_STREAM,"NETCONF").

-define(error(ConnName,Report),
	error_logger:error_report([{ct_connection,ConnName},
				   {client,self()},
				   {module,?MODULE},
				   {line,?LINE} |
				   Report])).

-define(is_timeout(T), (is_integer(T) orelse T==infinity)).
-define(is_filter(F),
	(?is_simple_xml(F)
	 orelse (F==[])
	 orelse (is_list(F) andalso ?is_simple_xml(hd(F))))).
-define(is_simple_xml(Xml),
	(is_atom(Xml) orelse (is_tuple(Xml) andalso is_atom(element(1,Xml))))).
-define(is_string(S), (is_list(S) andalso is_integer(hd(S)))).

%% Keys into the process dictionary.
-define(KEY(T), {?MODULE, T}).

%%----------------------------------------------------------------------
%% Records
%%----------------------------------------------------------------------
%% Client state
-record(state, {host,
		port,
		connection,      % #connection
		capabilities,
		session_id,
		msg_id = 1,
		hello_status,    % undefined | received | #pending{}
                                 % string() | {error, Reason}
		buf = false,     % binary() | list() | boolean()
		pending = [],    % [#pending]
		receivers = [] :: list() | pid()}).% notification destinations

%% Run-time client options.
-record(options, {ssh = [], % Options for the ssh application
		  host,
		  port = ?DEFAULT_PORT,
		  timeout = ?DEFAULT_TIMEOUT,
                  receivers = [],
		  name,
                  type}).

%% Connection reference
-record(connection, {reference, % {CM,Ch}
		     host,
		     port,
		     name,
                     type}).

%% Pending replies from server
-record(pending, {tref :: false | reference(),  % timer reference
		  msg_id,
                  op,
		  caller}).% pid which sent the request

%%----------------------------------------------------------------------
%% Type declarations
%%----------------------------------------------------------------------
-doc "Handle to a NETCONF session, as required by signaling functions.".
-type client() :: handle() | server_id() | ct:target_name().
-doc """
Handle to a connection to a NETCONF server as returned by
[`connect/1,2`](`connect/1`), or to a session as returned by
[`session/1-3`](`session/1`), [`open/1,2`](`open/1`), or
[`only_open/1,2`](`only_open/1`).
""".
-opaque handle() :: pid().

-doc """
Options `host` and `port` specify the server endpoint to which to connect, and
are passed directly to [`ssh:connect/4`](`ssh:connect/3`), as are arbitrary ssh
options. Common options are `user`, `password` and `user_dir`.

Option `timeout` specifies the number of milliseconds to allow for connection
establishment and, if the function in question results in an outgoing hello
message, reception of the server hello. The timeout applies to connection and
hello independently; one timeout for connection establishment, another for hello
reception.

Option `receiver` specifies a destination for incoming notification messages; a
left operand of the send operator (`!`). If not specified then a process calling
[`create_subscription/2,3`](`create_subscription/2`) becomes the receiver, but
explicitly setting a receiver makes it possible to receive notifications that
are not ordered by calling this function. Multiple receiver options can be
specified.

Receiver options are ignored by connect/1-3.

Option `capability` specifies the content of a corresponding element in an
outgoing hello message, each option specifying the content of a single element.
If no base NETCONF capability is configured then the RFC 4741 1.0 capability,
"urn:ietf:params:netconf:base:1.0", is added, otherwise not. In particular, the
RFC 6241 1.1 capability must be explicitly configured. NETCONF capabilities can
be specified using the shorthand notation defined in RFC 6241, any capability
string starting with a colon being prefixed by either "urn:ietf:params:netconf"
or "urn:ietf:params:netconf:capability", as appropriate.

Capability options are ignored by connect/1-3 and only_open/1-2, which don't
result in an outgoing hello message.
""".
-type option() :: {host | ssh, host()}
                | {port, inet:port_number()}
                | {timeout, timeout()}
                | {capability, string() | [string()]}
                | {receiver, term()}
                | ssh:client_option().

-type session_option() :: {timeout,timeout()}
                        | {receiver, term()}
                        | {capability, string() | [string()]}.

-type host() :: inet:hostname() | inet:ip_address().

-doc """
Event notification messages sent as a result of calls to
[`create_subscription/2,3`](`create_subscription/2`).
""".
-type notification() :: {notification, xml_attributes(), [simple_xml()]}.

-type stream_name() :: string().
-doc """
Stream information as returned by
[`get_event_streams/1-3`](`get_event_streams/1`). See RFC 5277, "XML Schema for
Event Notifications", for detail on the format of the string values.
""".
-type streams() :: [{stream_name(),[stream_data()]}].
-type stream_data() :: {description,string()} |
		       {replaySupport,string()} |
		       {replayLogCreationTime,string()} |
		       {replayLogAgedTime,string()}.
%% See XML Schema for Event Notifications found in RFC5277 for further
%% detail about the data format for the string values.

-type error_reason() :: term().

-doc "Identity of connection or session configuration in a configuration file.".
-type server_id() :: atom().

-doc """
Representation of XML, as described in application
[`xmerl`](`e:xmerl:index.html`).
""".
-type simple_xml() :: {xml_tag(), xml_attributes(), xml_content()} |
		      {xml_tag(), xml_content()} |
		      xml_tag().
-type xml_tag() :: atom().
-type xml_attributes() :: [{xml_attribute_tag(),xml_attribute_value()}].
-type xml_attribute_tag() :: atom().
-type xml_attribute_value() :: string().
-type xml_content() :: [simple_xml() | iolist()].
-type xpath() :: {xpath,string()}.

-type netconf_db() :: running | startup | candidate.
-doc """
Date and time of a startTime/stopTime element in an RFC 5277 create-subscription
request. Of XML primitive type `dateTime`, which has the (informal) form

```text
[-]YYYY-MM-DDThh:mm:ss[.s][Z|(+|-)hh:mm]
```

where `T` and `Z` are literal and `.s` is one or more fractional seconds.
""".
-type xs_datetime() :: string().
%% This date and time identifyer has the same format as the XML type
%% dateTime and compliant to RFC3339. The format is
%% "[-]CCYY-MM-DDThh:mm:ss[.s][Z|(+|-)hh:mm]"

%%----------------------------------------------------------------------
%% External interface functions
%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%% Open an SSH connection to a Netconf server
%% If the server options are specified in a configuration file, use
%% open/2.

%% connect/1

-doc """
Opens an SSH connection to a NETCONF server.

If the server options are specified in a configuration file, use `connect/2`
instead.

The opaque `t:handle/0` reference returned from this function is required as
connection identifier when opening sessions over this connection, see
[`session/1-3`](`session/1`).
""".
-doc(#{since => <<"OTP 20.0">>}).
-spec connect(Options) -> Result when
      Options :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.
connect(Options) ->
    connect(Options, #options{type = connection}, []).

%% connect/2

-doc """
Open an SSH connection to a named NETCONF server.

If `KeyOrName` is a configured `t:server_id/0` or a `target_name()` associated
with such an Id, then the options for this server are fetched from the
configuration file.

The options list is added to those of the configuration file. If an option is
specified in both lists, the configuration file takes precedence.

If the server is not specified in a configuration file, use `connect/1` instead.

The opaque `t:handle/0` reference returned from this function can be used as
connection identifier when opening sessions over this connection, see
[`session/1-3`](`session/1`). However, if `KeyOrName` is a `target_name()`, that
is, if the server is named through a call to `ct:require/2` or a `require`
statement in the test suite, then this name can be used instead of `t:handle/0`.
""".
-doc(#{since => <<"OTP 20.0">>}).
-spec connect(KeyOrName, ExtraOptions) -> Result when
      KeyOrName :: ct:key_or_name(),
      ExtraOptions :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.

connect(KeyOrName, ExtraOptions) ->
    connect(make_opts(KeyOrName, ExtraOptions),
            #options{name = KeyOrName, type = connection},
            [{name, KeyOrName}]).

%% connect/3

connect(Opts, InitRec, NameOpt) ->
    case make_options(Opts, InitRec) of
        #options{} = Rec ->
            start(Rec, NameOpt, false);
        {error, _} = No ->
            No
    end.

%% make_opts/2

make_opts(KeyOrName, ExtraOptions) ->
    SortedExtra = lists:keysort(1, ExtraOptions),
    SortedConfig = lists:keysort(1, ct:get_config(KeyOrName, [])),
    lists:ukeymerge(1, SortedConfig, SortedExtra).

%%----------------------------------------------------------------------
%% Close the given SSH connection.
-doc """
Closes the given SSH connection.

If there are open NETCONF sessions on the connection, these will be brutally
aborted. To avoid this, close each session with
[`close_session/1,2`](`close_session/1`)
""".
-doc(#{since => <<"OTP 20.0">>}).
-spec disconnect(Conn) -> ok | {error,error_reason()} when
      Conn :: handle().
disconnect(Conn) ->
    case call(Conn,get_ssh_connection) of
        {ok,_} ->
            ct_gen_conn:stop(Conn);
        Error ->
            Error
    end.

%%----------------------------------------------------------------------
%% Open a netconf session as a channel on the given SSH connection,
%% and exchange `hello' messages.

%% session/1

-doc(#{equiv => session/3}).
-doc(#{since => <<"OTP 20.0">>}).
-spec session(Conn) -> Result when
      Conn :: handle(),
      Result :: {ok, handle()} | {error, error_reason()}.

session(Conn) ->
    session(Conn, [], #options{type = channel}, []).

%% session/2

-doc(#{equiv => session/3}).
-doc(#{since => <<"OTP 20.0">>}).
-spec session(Conn, Options) -> Result when
      Conn :: handle(),
      Options :: [session_option()],
      Result :: {ok, handle()} | {error, error_reason()};
             (KeyOrName, Conn) -> Result when
      KeyOrName :: ct:key_or_name(),
      Conn :: handle(),
      Result :: {ok, handle()} | {error, error_reason()}.

session(Conn, Options) when is_list(Options) ->
    session(Conn, Options, #options{type = channel}, []);

session(KeyOrName, Conn) ->
    session(Conn,
            [],
            #options{name = KeyOrName, type = channel},
            [{name, KeyOrName}]).

%% session/3

-doc """
Opens a NETCONF session as a channel on the given SSH connection, and exchanges
hello messages with the server.

The opaque `t:handle/0` reference returned from this function can be used as
client identifier when calling any other function in this module. However, if
`KeyOrName` is used and it is a `target_name()`, that is, if the server is named
through a call to `ct:require/2` or a `require` statement in the test suite,
then this name can be used instead of `t:handle/0`.
""".
-doc(#{since => <<"OTP 20.0">>}).
-spec session(KeyOrName, Conn, Options) -> Result when
      Conn :: handle(),
      Options :: [session_option()],
      KeyOrName :: ct:key_or_name(),
      Result :: {ok, handle()} | {error, error_reason()}.

session(KeyOrName, Conn, ExtraOptions) ->
    session(Conn,
            make_opts(KeyOrName, ExtraOptions),
            #options{name = KeyOrName, type = channel},
            [{name, KeyOrName}]).

%% session/4

session(Conn, Opts, InitRec, NameOpt) ->
    T = make_ref(),
    try
        [_ | {ok, SshConn}] = [T | call(Conn, get_ssh_connection)],
        [_ | #options{} = Rec] = [T | make_session_options(Opts, InitRec)],
        [_ | {ok, Client} = Ok] = [T | start(SshConn, Rec, NameOpt, true)],
        [_ | ok] = [T | hello(Client, caps(Opts), Rec#options.timeout)],
        Ok
    catch
        error: {badmatch, [T | Error]} ->
            Error
    end.

%% caps/1

caps(Opts) ->
    [T || {capability, _} = T <- Opts].

%%----------------------------------------------------------------------
%% Open a netconf session and exchange 'hello' messages.
%% If the server options are specified in a configuration file, use
%% open/2.

%% open/1

-doc """
Opens a NETCONF session and exchanges `hello` messages.

If the server options are specified in a configuration file, or if a named
client is needed for logging purposes (see section
[Logging](`m:ct_netconfc#Logging`) in this module), use `open/2` instead.

The opaque `t:handle/0` reference returned from this function is required as
client identifier when calling any other function in this module.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec open(Options) -> Result when
      Options :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.

open(Options) ->
    open(Options,
         #options{type = connection_and_channel},
         [],
         true).

-doc """
Opens a named NETCONF session and exchanges `hello` messages.

If `KeyOrName` is a configured `t:server_id/0` or a `target_name()` associated
with such an Id, then the options for this server are fetched from the
configuration file.

The options list is added to those of the configuration file. If an option is
specified in both lists, the configuration file take precedence.

If the server is not specified in a configuration file, use `open/1` instead.

The opaque `t:handle/0` reference returned from this function can be used as
client identifier when calling any other function in this module. However, if
`KeyOrName` is a `target_name()`, that is, if the server is named through a call
to `ct:require/2` or a `require` statement in the test suite, then this name can
be used instead of `t:handle/0`.

See also `ct:require/2`.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec open(KeyOrName, ExtraOption) -> Result when
      KeyOrName :: ct:key_or_name(),
      ExtraOption :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.

open(KeyOrName, ExtraOpts) ->
    open(KeyOrName, ExtraOpts, true).

%% open/3

open(KeyOrName, ExtraOptions, Hello) ->
    open(make_opts(KeyOrName, ExtraOptions),
         #options{name = KeyOrName, type = connection_and_channel},
         [{name, KeyOrName}],
         Hello).

%% open/4

open(Opts, InitRec, NameOpt, Hello) ->
    T = make_ref(),
    try
        [_, #options{} = Rec] = [T, make_options(Opts, InitRec)],
        [_, {ok, Client} = Ok | true] = [T, start(Rec, NameOpt, true) | Hello],
        [_, ok] = [T, hello(Client, caps(Opts), Rec#options.timeout)],
        Ok
    catch
        error: {badmatch, [T, Res | _]} ->
            Res
    end.

%% start/3

start(#options{host = undefined}, _, _) ->
    {error, no_host_address};

start(#options{port = undefined}, _, _) ->
    {error, no_port};

start(#options{host = Host, port = Port} = Opts, NameOpt, Fwd) ->
    start({Host, Port}, Opts, NameOpt, Fwd).

%% start/4

start(Ep, Opts, NameOpt, Fwd) ->
    ct_gen_conn:start(Ep, Opts, ?MODULE, [{reconnect, false},
                                          {use_existing_connection, false},
                                          {forward_messages, Fwd}
                                          | NameOpt]).

%%----------------------------------------------------------------------
%% Like open/1,2, but no 'hello' message is sent.

-doc """
Opens a NETCONF session, but does not send `hello`.

As `open/1`, but does not send a `hello` message.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec only_open(Options) -> Result when
      Options :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.

only_open(Options) ->
    open(Options, #options{type = connection_and_channel}, [], false).

-doc """
Opens a named NETCONF session, but does not send `hello`.

As `open/2`, but does not send a `hello` message.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec only_open(KeyOrName, ExtraOptions) -> Result when
      KeyOrName :: ct:key_or_name(),
      ExtraOptions :: [option()],
      Result :: {ok, handle()} | {error, error_reason()}.

only_open(KeyOrName, ExtraOpts) ->
    open(KeyOrName, ExtraOpts, false).

%%----------------------------------------------------------------------
%% Send a 'hello' message.

%% hello/1

-doc(#{equiv => hello/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec hello(Client) -> Result when
      Client :: handle(),
      Result :: ok | {error, error_reason()}.

hello(Client) ->
    hello(Client, [], ?DEFAULT_TIMEOUT).

%% hello/2

-doc(#{equiv => hello/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec hello(Client, Timeout) -> Result when
      Client :: handle(),
      Timeout :: timeout(),
      Result :: ok | {error, error_reason()}.

hello(Client, Timeout) ->
    hello(Client, [], Timeout).

%% hello/3

-doc """
Exchanges `hello` messages with the server. Returns when the server hello has
been received or after the specified timeout.

Note that capabilities for an outgoing hello can be passed directly to `open/2`.
""".
-doc(#{since => <<"OTP 17.5.3">>}).
-spec hello(Client, Options, Timeout) -> Result when
      Client :: handle(),
      Options :: [{capability, [string()]}],
      Timeout :: timeout(),
      Result :: ok | {error, error_reason()}.

hello(Client, Options, Timeout) ->
    call(Client, {hello, Options, Timeout}).


%%----------------------------------------------------------------------
%% Get the session id for the session specified by Client.
-doc(#{equiv => get_session_id/2}).
-doc(#{since => <<"OTP R15B02">>}).
-spec get_session_id(Client) -> Result when
      Client :: client(),
      Result :: pos_integer() | {error,error_reason()}.
get_session_id(Client) ->
    get_session_id(Client, ?DEFAULT_TIMEOUT).

-doc "Returns the session Id associated with the specified client.".
-doc(#{since => <<"OTP R15B02">>}).
-spec get_session_id(Client, Timeout) -> Result when
      Client :: client(),
      Timeout :: timeout(),
      Result :: pos_integer() | {error,error_reason()}.
get_session_id(Client, Timeout) ->
    call(Client, get_session_id, Timeout).

%%----------------------------------------------------------------------
%% Get the server side capabilities.
-doc(#{equiv => get_capabilities/2}).
-doc(#{since => <<"OTP R15B02">>}).
-spec get_capabilities(Client) -> Result when
      Client :: client(),
      Result :: [string()] | {error,error_reason()}.
get_capabilities(Client) ->
    get_capabilities(Client, ?DEFAULT_TIMEOUT).

-doc "Returns the server capabilities as received in its hello message.".
-doc(#{since => <<"OTP R15B02">>}).
-spec get_capabilities(Client, Timeout) -> Result when
      Client :: client(),
      Timeout :: timeout(),
      Result :: [string()] | {error,error_reason()}.
get_capabilities(Client, Timeout) ->
    call(Client, get_capabilities, Timeout).

%%----------------------------------------------------------------------
%% Send an XML document to the server.
-doc(#{equiv => send/3}).
-doc(#{since => <<"OTP R16B02">>}).
-spec send(Client, SimpleXml) -> Result when
      Client :: client(),
      SimpleXml :: simple_xml(),
      Result :: simple_xml() | {error,error_reason()}.
send(Client, SimpleXml) ->
    send(Client, SimpleXml, ?DEFAULT_TIMEOUT).

-doc """
Sends an XML document to the server.

The specified XML document is sent "as is" to the server. This function can be
used for sending XML documents that cannot be expressed by other interface
functions in this module.
""".
-doc(#{since => <<"OTP R16B02">>}).
-spec send(Client, SimpleXml, Timeout) -> Result when
      Client :: client(),
      SimpleXml :: simple_xml(),
      Timeout :: timeout(),
      Result :: simple_xml() | {error,error_reason()}.
send(Client, SimpleXml, Timeout) ->
    call(Client,{send, Timeout, SimpleXml}).

%%----------------------------------------------------------------------
%% Wrap the given XML document in a valid netconf 'rpc' request and
%% send to the server.
-doc(#{equiv => send_rpc/3}).
-doc(#{since => <<"OTP R16B02">>}).
-spec send_rpc(Client, SimpleXml) -> Result when
      Client :: client(),
      SimpleXml :: simple_xml(),
      Result :: [simple_xml()] | {error,error_reason()}.
send_rpc(Client, SimpleXml) ->
    send_rpc(Client, SimpleXml, ?DEFAULT_TIMEOUT).

-doc """
Sends a NETCONF `rpc` request to the server.

The specified XML document is wrapped in a valid NETCONF `rpc` request and sent
to the server. The `message-id` and namespace attributes are added to element
`rpc`.

This function can be used for sending `rpc` requests that cannot be expressed by
other interface functions in this module.
""".
-doc(#{since => <<"OTP R16B02">>}).
-spec send_rpc(Client, SimpleXml, Timeout) -> Result when
      Client :: client(),
      SimpleXml :: simple_xml(),
      Timeout :: timeout(),
      Result :: [simple_xml()] | {error,error_reason()}.
send_rpc(Client, SimpleXml, Timeout) ->
    call(Client,{send_rpc, SimpleXml, Timeout}).

%%----------------------------------------------------------------------
%% Send a 'lock' request.
-doc(#{equiv => lock/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec lock(Client, Target) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Result :: ok | {error,error_reason()}.
lock(Client, Target) ->
    lock(Client, Target,?DEFAULT_TIMEOUT).

-doc """
Locks the configuration target.

Which target parameters that can be used depends on if `:candidate` and/or
`:startup` are supported by the server. If successful, the configuration system
of the device is unavailable to other clients (NETCONF, CORBA, SNMP, and so on).
Locks are intended to be short-lived.

Operation [`kill_session/2,3`](`kill_session/2`) can be used to force the
release of a lock owned by another NETCONF session. How this is achieved by the
server side is implementation-specific.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec lock(Client, Target, Timeout) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
lock(Client, Target, Timeout) ->
    call(Client,{send_rpc_op,lock,[Target],Timeout}).

%%----------------------------------------------------------------------
%% Send a 'unlock' request.
-doc(#{equiv => unlock/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec unlock(Client, Target) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Result :: ok | {error,error_reason()}.
unlock(Client, Target) ->
    unlock(Client, Target,?DEFAULT_TIMEOUT).

-doc """
Unlocks the configuration target.

If the client earlier has acquired a lock through [`lock/2,3`](`lock/2`), this
operation releases the associated lock. To access another target than `running`,
the server must support `:candidate` and/or `:startup`.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec unlock(Client, Target, Timeout) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
unlock(Client, Target, Timeout) ->
    call(Client, {send_rpc_op, unlock, [Target], Timeout}).

%%----------------------------------------------------------------------
%% Send a 'get' request.
-doc(#{equiv => get/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec get(Client, Filter) -> Result when
      Client :: client(),
      Filter :: simple_xml() | xpath(),
      Result :: {ok,[simple_xml()]} | {error,error_reason()}.
get(Client, Filter) ->
    get(Client, Filter, ?DEFAULT_TIMEOUT).

-doc """
Gets data.

This operation returns both configuration and state data from the server.

Filter type `xpath` can be used only if the server supports `:xpath`.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec get(Client, Filter, Timeout) -> Result when
      Client :: client(),
      Filter :: simple_xml() | xpath(),
      Timeout :: timeout(),
      Result :: {ok,[simple_xml()]} | {error,error_reason()}.
get(Client, Filter, Timeout) ->
    call(Client,{send_rpc_op, get, [Filter], Timeout}).

%%----------------------------------------------------------------------
%% Send a 'get-config' request.
-doc(#{equiv => get_config/4}).
-doc(#{since => <<"OTP R15B02">>}).
-spec get_config(Client, Source, Filter) -> Result when
      Client :: client(),
      Source :: netconf_db(),
      Filter :: simple_xml() | xpath(),
      Result :: {ok,[simple_xml()]} | {error,error_reason()}.
get_config(Client, Source, Filter) ->
    get_config(Client, Source, Filter, ?DEFAULT_TIMEOUT).

-doc """
Gets configuration data.

To be able to access another source than `running`, the server must advertise
`:candidate` and/or `:startup`.

Filter type `xpath` can be used only if the server supports `:xpath`.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec get_config(Client, Source, Filter, Timeout) -> Result when
      Client :: client(),
      Source :: netconf_db(),
      Filter :: simple_xml() | xpath(),
      Timeout :: timeout(),
      Result :: {ok,[simple_xml()]} | {error,error_reason()}.
get_config(Client, Source, Filter, Timeout) ->
    call(Client, {send_rpc_op, get_config, [Source, Filter], Timeout}).

%%----------------------------------------------------------------------
%% Send a 'edit-config' request.
-doc(#{equiv => edit_config/5}).
-doc(#{since => <<"OTP R15B02">>}).
-spec edit_config(Client, Target, Config) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Config :: simple_xml() | [simple_xml()],
      Result :: ok | {error,error_reason()}.
edit_config(Client, Target, Config) ->
    edit_config(Client, Target, Config, ?DEFAULT_TIMEOUT).

-doc(#{equiv => edit_config/5}).
-doc(#{since => <<"OTP R15B02">>}).
-spec edit_config(Client, Target, Config, OptParams) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Config :: simple_xml() | [simple_xml()],
      OptParams :: [simple_xml()],
      Result :: ok | {error,error_reason()};
                 (Client, Target, Config, Timeout) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Config :: simple_xml(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
edit_config(Client, Target, Config, Timeout) when ?is_timeout(Timeout) ->
    edit_config(Client, Target, Config, [], Timeout);
edit_config(Client, Target, Config, OptParams) when is_list(OptParams) ->
    edit_config(Client, Target, Config, OptParams, ?DEFAULT_TIMEOUT).

-doc """
Edits configuration data.

By default only the running target is available, unless the server includes
`:candidate` or `:startup` in its list of capabilities.

`OptParams` can be used for specifying optional parameters (`default-operation`,
`test-option`, or `error-option`) to be added to the `edit-config` request. The
value must be a list containing valid simple XML, for example:

```erlang
[{'default-operation', ["none"]},
 {'error-option', ["rollback-on-error"]}]
```

If `OptParams` is not given, the default value `[]` is used.
""".
-doc(#{since => <<"OTP 18.0">>}).
-spec edit_config(Client, Target, Config, OptParams, Timeout) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Config :: simple_xml() | [simple_xml()],
      OptParams :: [simple_xml()],
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
edit_config(Client, Target, Config, OptParams, Timeout) when not is_list(Config)->
    edit_config(Client, Target, [Config], OptParams, Timeout);
edit_config(Client, Target, Config, OptParams, Timeout) ->
    call(Client, {send_rpc_op, edit_config, [Target,Config,OptParams], Timeout}).


%%----------------------------------------------------------------------
%% Send a 'delete-config' request.
-doc(#{equiv => delete_config/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec delete_config(Client, Target) -> Result when
      Client :: client(),
      Target :: startup | candidate,
      Result :: ok | {error,error_reason()}.
delete_config(Client, Target) ->
    delete_config(Client, Target, ?DEFAULT_TIMEOUT).

-doc """
Deletes configuration data.

The running configuration cannot be deleted and `:candidate` or `:startup` must
be advertised by the server.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec delete_config(Client, Target, Timeout) -> Result when
      Client :: client(),
      Target :: startup | candidate,
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
delete_config(Client, Target, Timeout) when Target == startup;
					    Target == candidate ->
    call(Client,{send_rpc_op, delete_config, [Target], Timeout}).

%%----------------------------------------------------------------------
%% Send a 'copy-config' request.
-doc(#{equiv => copy_config/4}).
-doc(#{since => <<"OTP R15B02">>}).
-spec copy_config(Client, Target, Source) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Source :: netconf_db(),
      Result :: ok | {error,error_reason()}.
copy_config(Client, Source, Target) ->
    copy_config(Client, Source, Target, ?DEFAULT_TIMEOUT).

-doc """
Copies configuration data.

Which source and target options that can be issued depends on the capabilities
supported by the server. That is, `:candidate` and/or `:startup` are required.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec copy_config(Client, Target, Source, Timeout) -> Result when
      Client :: client(),
      Target :: netconf_db(),
      Source :: netconf_db(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
copy_config(Client, Target, Source, Timeout) ->
    call(Client,{send_rpc_op, copy_config, [Target, Source], Timeout}).

%%----------------------------------------------------------------------
%% Execute an action.
-doc(#{equiv => action/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec action(Client, Action) -> Result when
      Client :: client(),
      Action :: simple_xml(),
      Result :: ok | {ok,[simple_xml()]} | {error,error_reason()}.
action(Client,Action) ->
    action(Client,Action,?DEFAULT_TIMEOUT).

-doc """
Executes an action. If the return type is void, `ok` is returned instead of
`{ok,[simple_xml()]}`.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec action(Client, Action, Timeout) -> Result when
      Client :: client(),
      Action :: simple_xml(),
      Timeout :: timeout(),
      Result :: ok | {ok,[simple_xml()]} | {error,error_reason()}.
action(Client,Action,Timeout) ->
    call(Client,{send_rpc_op, action, [Action], Timeout}).

%%----------------------------------------------------------------------
%% Send a 'create-subscription' request
%% See RFC5277, NETCONF Event Notifications

%% create_subscription/2

-doc(#{equiv => create_subscription/3}).
-doc(#{since => <<"OTP 22.1">>}).
-spec create_subscription(Client, Values) -> Result when
      Client :: client(),
      Values :: #{stream => Stream,
                  filter => Filter,
                  start => StartTime,
                  stop => StopTime},
      Stream :: stream_name(),
      Filter :: simple_xml() | [simple_xml()],
      StartTime :: xs_datetime(),
      StopTime :: xs_datetime(),
      Result :: ok | {error,error_reason()};
      %% historic, no longer documented
                         (Client, list() | timeout()) -> Result when
      Client :: client(),
      Result :: ok | {error,error_reason()}.

create_subscription(Client, #{} = Values) ->
    create_subscription(Client, Values, ?DEFAULT_TIMEOUT);

%% historic clauses
create_subscription(Client, Timeout)
  when ?is_timeout(Timeout) ->
    create_subscription(Client, #{}, Timeout);
create_subscription(Client, Stream)
  when ?is_string(Stream) ->
    create_subscription(Client, #{stream => Stream});
create_subscription(Client, Filter)
  when ?is_filter(Filter) ->
    create_subscription(Client, #{filter => Filter}).

-doc """
Creates a subscription for event notifications by sending an RFC 5277
create-subscription RPC to the server. The calling process receives events as
messages of type `t:notification/0`.

From RFC 5722, 2.1 Subscribing to Receive Event Notifications:

- **`Stream`** - Indicates which stream of event is of interest. If not present,
  events in the default NETCONF stream are sent.

- **`Filter`** - Indicates which subset of all possible events is of interest.
  The parameter format is the same as that of the filter parameter in the
  NETCONF protocol operations. If not present, all events not precluded by other
  parameters are sent.

- **`StartTime`** - Used to trigger the replay feature and indicate that the
  replay is to start at the time specified. If `StartTime` is not present, this
  is not a replay subscription. It is not valid to specify start times that are
  later than the current time. If `StartTime` is specified earlier than the log
  can support, the replay begins with the earliest available notification. This
  parameter is of type `dateTime` and compliant to RFC 3339. Implementations
  must support time zones.

- **`StopTime`** - Used with the optional replay feature to indicate the newest
  notifications of interest. If `StopTime` is not present, the notifications
  continues until the subscription is terminated. Must be used with and be later
  than `StartTime`. Values of `StopTime` in the future are valid. This parameter
  is of type `dateTime` and compliant to RFC 3339. Implementations must support
  time zones.

See RFC 5277 for more details. The requirement that `StopTime` must only be used
with `StartTime` is not enforced, to allow an invalid request to be sent to the
server.

Prior to OTP 22.1, this function was documented as having 15 variants in 6
arities. These are still exported for backwards compatibility, but no longer
documented. The map-based variants documented above provide the same
functionality with simpler arguments.

> #### Note {: .info }
>
> create-subscription is no longer the only RPC with which NETCONF notifications
> can be ordered: RFC 8639 adds establish-subscription and future RFCs may add
> other methods. Specify a `receiver` option at session creation to provide a
> destination for incoming notifications independently of a call to
> [`create_subscription/2,3`](`create_subscription/2`), and use
> [`send_rpc/2,3`](`send_rpc/2`) to send establish-subscription and other
> arbitrary RPCs.
""".
-doc(#{since => <<"OTP 22.1">>}).
-spec create_subscription(Client, Values, Timeout) -> Result when
      Client :: client(),
      Values :: #{stream => Stream,
                  filter => Filter,
                  start => StartTime,
                  stop => StopTime},
      Stream :: stream_name(),
      Filter :: simple_xml() | [simple_xml()],
      StartTime :: xs_datetime(),
      StopTime :: xs_datetime(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()};
      %% historic, no longer documented
                         (Client, list(), list() | timeout()) -> Result when
      Client :: client(),
      Result :: ok | {error,error_reason()}.

create_subscription(Client, #{} = Values, Timeout) ->
    Keys = [{stream, ?DEFAULT_STREAM},
            {filter, undefined},
            {start, undefined},
            {stop, undefined}],
    call(Client, {send_rpc_op, {create_subscription, self()},
                               [maps:get(K, Values, D) || {K,D} <- Keys],
                               Timeout});

%% historic clauses, arity 3
create_subscription(Client, Stream, Timeout)
  when ?is_string(Stream), ?is_timeout(Timeout) ->
    create_subscription(Client, #{stream => Stream}, Timeout);
create_subscription(Client, StartTime, StopTime)
  when ?is_string(StartTime), ?is_string(StopTime) ->
    create_subscription(Client, #{start => StartTime, stop => StopTime});
create_subscription(Client, Filter, Timeout)
  when ?is_filter(Filter), ?is_timeout(Timeout) ->
    create_subscription(Client, #{filter => Filter}, Timeout);
create_subscription(Client, Stream, Filter)
  when ?is_string(Stream), ?is_filter(Filter) ->
    create_subscription(Client, #{stream => Stream, filter => Filter}).

%% historic clauses, arity 1,4-5
-doc false.
create_subscription(Client) ->
    create_subscription(Client, #{}).
-doc false.
create_subscription(Client, StartTime, StopTime, Timeout)
  when ?is_string(StartTime), ?is_string(StopTime), ?is_timeout(Timeout) ->
    Values = #{start => StartTime,
               stop => StopTime},
    create_subscription(Client, Values, Timeout);
create_subscription(Client, Stream, StartTime, StopTime)
  when ?is_string(Stream), ?is_string(StartTime), ?is_string(StopTime) ->
    create_subscription(Client, #{stream => Stream,
                                  start => StartTime,
                                  stop => StopTime});
create_subscription(Client, Filter, StartTime, StopTime)
  when ?is_filter(Filter), ?is_string(StartTime), ?is_string(StopTime) ->
    create_subscription(Client, #{filter => Filter,
                                  start => StartTime,
                                  stop => StopTime});
create_subscription(Client, Stream, Filter, Timeout)
  when ?is_string(Stream), ?is_filter(Filter), ?is_timeout(Timeout) ->
    Values = #{stream => Stream,
               filter => Filter},
    create_subscription(Client, Values, Timeout).
-doc false.
create_subscription(Client, Stream, StartTime, StopTime, Timeout)
  when ?is_string(Stream), ?is_string(StartTime), ?is_string(StopTime),
       ?is_timeout(Timeout) ->
    Values = #{stream => Stream,
               start => StartTime,
               stop => StopTime},
    create_subscription(Client, Values, Timeout);
create_subscription(Client, Stream, Filter, StartTime, StopTime)
  when ?is_string(Stream), ?is_filter(Filter), ?is_string(StartTime),
       ?is_string(StopTime) ->
    create_subscription(Client, #{stream => Stream,
                                  filter => Filter,
                                  start => StartTime,
                                  stop => StopTime}).
-doc false.
create_subscription(Client, Stream, Filter, StartTime, StopTime, Timeout) ->
    Values = #{stream => Stream,
               filter => Filter,
               start => StartTime,
               stop => StopTime},
    create_subscription(Client, Values, Timeout).

%%----------------------------------------------------------------------
%% Send a request to get the given event streams
%% See RFC5277, NETCONF Event Notifications
-doc(#{equiv => get_event_streams/3}).
-doc(#{since => <<"OTP 20.0">>}).
-spec get_event_streams(Client)
		       -> Result when
      Client :: client(),
      Result :: {ok,streams()} | {error,error_reason()}.
get_event_streams(Client) ->
    get_event_streams(Client,[],?DEFAULT_TIMEOUT).

-doc(#{equiv => get_event_streams/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec get_event_streams(Client, Timeout)
		       -> Result when
      Client :: client(),
      Timeout :: timeout(),
      Result :: {ok,streams()} | {error,error_reason()};
                       (Client, Streams) -> Result when
      Client :: client(),
      Streams :: [stream_name()],
      Result :: {ok,streams()} | {error,error_reason()}.
get_event_streams(Client,Timeout) when is_integer(Timeout); Timeout==infinity ->
    get_event_streams(Client,[],Timeout);
get_event_streams(Client,Streams) when is_list(Streams) ->
    get_event_streams(Client,Streams,?DEFAULT_TIMEOUT).

-doc """
Sends a request to get the specified event streams.

`Streams` is a list of stream names. The following filter is sent to the NETCONF
server in a `get` request:

```text
<netconf xmlns="urn:ietf:params:xml:ns:netmod:notification">
  <streams>
    <stream>
      <name>StreamName1</name>
    </stream>
    <stream>
      <name>StreamName2</name>
    </stream>
    ...
  </streams>
</netconf>
```

If `Streams` is an empty list, _all_ streams are requested by sending the
following filter:

```text
<netconf xmlns="urn:ietf:params:xml:ns:netmod:notification">
  <streams/>
</netconf>
```

If more complex filtering is needed, use [`ct_netconfc:get/2,3`](`get/2`) and
specify the exact filter according to "XML Schema for Event Notifications" in
RFC 5277.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec get_event_streams(Client, Streams, Timeout)
		       -> Result when
      Client :: client(),
      Streams :: [stream_name()],
      Timeout :: timeout(),
      Result :: {ok,streams()} | {error,error_reason()}.
get_event_streams(Client,Streams,Timeout) ->
    call(Client,{get_event_streams,Streams,Timeout}).


%%----------------------------------------------------------------------
%% Send a 'close-session' request
-doc(#{equiv => close_session/2}).
-doc(#{since => <<"OTP R15B02">>}).
-spec close_session(Client) -> Result when
      Client :: client(),
      Result :: ok | {error,error_reason()}.
close_session(Client) ->
    close_session(Client, ?DEFAULT_TIMEOUT).

-doc """
Requests graceful termination of the session associated with the client.

When a NETCONF server receives a `close-session` request, it gracefully closes
the session. The server releases any locks and resources associated with the
session and gracefully closes any associated connections. Any NETCONF requests
received after a `close-session` request are ignored.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec close_session(Client, Timeout) -> Result when
      Client :: client(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
close_session(Client, Timeout) ->
    call(Client,{send_rpc_op, close_session, [], Timeout}, true).


%%----------------------------------------------------------------------
%% Send a 'kill-session' request
-doc(#{equiv => kill_session/3}).
-doc(#{since => <<"OTP R15B02">>}).
-spec kill_session(Client, SessionId) -> Result when
      Client :: client(),
      SessionId :: pos_integer(),
      Result :: ok | {error,error_reason()}.
kill_session(Client, SessionId) ->
    kill_session(Client, SessionId, ?DEFAULT_TIMEOUT).

-doc """
Forces termination of the session associated with the supplied session Id.

The server side must abort any ongoing operations, release any locks and
resources associated with the session, and close any associated connections.

Only if the server is in the confirmed commit phase, the configuration is
restored to its state before entering the confirmed commit phase. Otherwise, no
configuration rollback is performed.

If the specified `SessionId` is equal to the current session Id, an error is
returned.
""".
-doc(#{since => <<"OTP R15B02">>}).
-spec kill_session(Client, SessionId, Timeout) -> Result when
      Client :: client(),
      SessionId :: pos_integer(),
      Timeout :: timeout(),
      Result :: ok | {error,error_reason()}.
kill_session(Client, SessionId, Timeout) ->
    call(Client,{send_rpc_op, kill_session, [SessionId], Timeout}).


%%----------------------------------------------------------------------
%% Callback functions
%%----------------------------------------------------------------------

%% init/3

-doc false.
init(_KeyOrName,{CM,{Host,Port}},Options) ->
    case ssh_channel(#connection{reference=CM,host=Host,port=Port},Options) of
        {ok,Connection} ->
	    {ok, CM, #state{connection = Connection,
                            receivers = Options#options.receivers}};
	{error,Reason}->
	    {error,Reason}
    end;
init(_KeyOrName,{_Host,_Port},Options) when Options#options.type==connection ->
    case ssh_connect(Options) of
        {ok, Connection} ->
	    ConnPid = Connection#connection.reference,
            {ok, ConnPid, #state{connection = Connection}};
        Error ->
            Error
    end;
init(_KeyOrName,{_Host,_Port},Options) ->
    case ssh_open(Options) of
	{ok, Connection} ->
	    {ConnPid,_} = Connection#connection.reference,
	    {ok, ConnPid, #state{connection = Connection,
                                 receivers = Options#options.receivers}};
	{error,Reason}->
	    {error,Reason}
    end.

%% terminate/2

-doc false.
terminate(_, #state{connection=Connection}) ->
    ssh_close(Connection),
    ok.

%% handle_msg/3

%% Send hello and return to the caller only after reception of the
%% server's hello.
-doc false.
handle_msg({hello, Options, Timeout},
           From,
	   #state{connection = Connection,
                  hello_status = HelloStatus}
           = State) ->
    case do_send(Connection, client_hello(Options)) of
	ok when HelloStatus == undefined -> %% server hello not yet received
            TRef = set_request_timer(Timeout, hello),
            {noreply, State#state{hello_status = #pending{tref = TRef,
                                                          caller = From}}};
        ok ->                               %% or yes: negotiate version
            handle_capx(State);
        Error ->
	    {stop, Error, State}
    end;

handle_msg(get_ssh_connection, _From, #state{connection=Connection}=State) ->
    Reply =
        case Connection#connection.reference of
            {_,_} -> {error,not_an_ssh_connection};
            CM -> {ok,{CM,{Connection#connection.host,
                           Connection#connection.port}}}
        end,
    {reply, Reply, State};

%% Request before server hello. Possible with only_open, since a
%% handle is then returned without waiting for the server.
handle_msg(_, _From, #state{session_id = undefined} = State) ->
    {reply, {error, waiting_for_hello}, State};

handle_msg(get_capabilities, _From, #state{capabilities = Caps} = State) ->
    {reply, Caps, State};

handle_msg(get_session_id, _From, #state{session_id = Id} = State) ->
    {reply, Id, State};

handle_msg({send, Timeout, SimpleXml},
           From,
           #state{connection = Connection,
                  pending = Pending}
           = State) ->
    case do_send(Connection, SimpleXml) of
        ok ->
            TRef = set_request_timer(Timeout, send),
            {noreply, State#state{pending = [#pending{tref = TRef,
                                                      caller = From}
                                             | Pending]}};
        Error ->
            {reply, Error, State}
    end;

handle_msg({send_rpc, SimpleXml, Timeout}, From, State) ->
    do_send_rpc(undefined, SimpleXml, Timeout, From, State);

handle_msg({send_rpc_op, Op, Data, Timeout}, From, State) ->
    SimpleXml = encode_rpc_operation(Op,Data),
    do_send_rpc(Op, SimpleXml, Timeout, From, State);

handle_msg({get_event_streams=Op,Streams,Timeout}, From, State) ->
    Filter = {netconf,?NETMOD_NOTIF_NAMESPACE_ATTR,
             [{streams,[{stream,[{name,[Name]}]} || Name <- Streams]}]},
    SimpleXml = encode_rpc_operation(get,[Filter]),
    do_send_rpc(Op, SimpleXml, Timeout, From, State).

-doc false.
handle_msg({ssh_cm, CM, {data, Ch, _Type, Data}}, State) when is_binary(Data) ->
    ssh_connection:adjust_window(CM,Ch,byte_size(Data)),
    log(State#state.connection, recv, Data),
    handle_data(Data, State);

handle_msg({ssh_cm, _CM, _SshCloseMsg}, State) ->
    %% _SshCloseMsg can probably be one of
    %% {eof,Ch}
    %% {exit_status,Ch,Status}
    %% {exit_signal,Ch,ExitSignal,ErrorMsg,LanguageString}
    %% {signal,Ch,Signal}

    %% This might e.g. happen if the server terminates the connection,
    %% as in kill-session (or if ssh:close is called from somewhere
    %% unexpected).

    %%! Log this??
    %%! Currently the log will say that the client closed the
    %%! connection - due to terminate/2

    {stop, State};

handle_msg({timeout, TRef, hello},
           #state{hello_status = #pending{tref = TRef,
                                          caller = From}}
           = State) ->
    ct_gen_conn:return(From, {error, {hello_session_failed, timeout}}),
    {stop, State#state{hello_status = {error,timeout}}};

handle_msg({timeout, TRef, Op}, #state{pending = Pending} = State) ->
    case lists:keytake(TRef, #pending.tref, Pending) of
        {value, #pending{caller = From}, Rest} ->
            ct_gen_conn:return(From, {error, timeout}),
            %% Discard received bytes in hope that the server has sent
            %% an incomplete message. Otherwise this is doomed to
            %% leave the connection in an unusable state.
            {if Op == close_session -> stop; true -> noreply end,
             State#state{pending = Rest,
                         buf = is_binary(State#state.buf)}};
        false ->
            {noreply, State}
    end.

%% close/1

%% Called by ct_util_server to close registered connections before terminate.
-doc false.
close(Client) ->
    case get_handle(Client) of
	{ok,Pid} ->
	    case ct_gen_conn:stop(Pid) of
		{error,{process_down,Pid,noproc}} ->
		    {error,already_closed};
		Result ->
		    Result
	    end;
	Error ->
	    Error
    end.


%%----------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------
call(Client, Msg) ->
    call(Client, Msg, infinity, false).
call(Client, Msg, Timeout) when is_integer(Timeout); Timeout==infinity ->
    call(Client, Msg, Timeout, false);
call(Client, Msg, WaitStop) when is_boolean(WaitStop) ->
    call(Client, Msg, infinity, WaitStop).
call(Client, Msg, Timeout, WaitStop) ->
    case get_handle(Client) of
	{ok,Pid} ->
	    case ct_gen_conn:call(Pid,Msg,Timeout) of
		{error,{process_down,Pid,noproc}} ->
		    {error,no_such_client};
		{error,{process_down,Pid,normal}} when WaitStop ->
		    %% This will happen when server closes connection
		    %% before client received rpc-reply on
		    %% close-session.
		    ok;
		{error,{process_down,Pid,normal}} ->
		    {error,closed};
		{error,{process_down,Pid,Reason}} ->
		    {error,{closed,Reason}};
		Other when WaitStop ->
		    MRef = erlang:monitor(process,Pid),
		    receive
			{'DOWN',MRef,process,Pid,Normal} when Normal==normal;
							      Normal==noproc ->
			    Other;
			{'DOWN',MRef,process,Pid,Reason} ->
			    {error,{{closed,Reason},Other}}
		    after Timeout ->
			    erlang:demonitor(MRef, [flush]),
			    {error,{timeout,Other}}
		    end;
		Other ->
		    Other
	    end;
	Error ->
	    Error
    end.

get_handle(Client) when is_pid(Client) ->
    {ok,Client};
get_handle(Client) ->
    case ct_util:get_connection(Client, ?MODULE) of
	{ok,{Pid,_}} ->
	    {ok,Pid};
	{error,no_registered_connection} ->
	    {error,{no_connection_found,Client}};
	Error ->
	    Error
    end.

%% make_options/2

make_options(Opts, Rec) ->
    make_options(Opts, Rec#options{port = undefined}, fun opt/2).

opt({T, Host}, Rec)
  when T == ssh;
       T == host ->
    Rec#options{host = Host};

opt({port, Port}, Rec) ->
    Rec#options{port = Port};

opt({timeout, Tmo}, Rec)
  when is_integer(Tmo);
       Tmo == infinity ->
    Rec#options{timeout = Tmo};

opt({timeout, _} = T, _) ->
    throw(T);

opt({capability, _}, Rec) ->
    Rec;

opt({receiver, Dest}, #options{receivers = T} = Rec) ->
    Rec#options{receivers = [Dest | T]};

opt(Opt, #options{ssh = Opts} = Rec) -> %% option verified by ssh
    Rec#options{ssh = [Opt | Opts]}.

%% make_session_options/2

make_session_options(Opts, Rec) ->
    make_options(Opts, Rec, fun session_opt/2).

session_opt({receiver, Dest}, #options{receivers = T} = Rec) ->
    Rec#options{receivers = [Dest | T]};

session_opt({capability, _}, Rec) ->
    Rec;

session_opt({timeout, Tmo}, Rec)
  when is_integer(Tmo);
       Tmo == infinity ->
    Rec#options{timeout = Tmo};

session_opt(T, _Rec) ->
    throw(T).

%% make_options/3

make_options(Opts, Rec, F) ->
    try
        #options{} = lists:foldl(F, Rec, Opts)
    catch
        T ->
            {error, {invalid_option, T}}
    end.

%%%-----------------------------------------------------------------

set_request_timer(infinity, _) ->
    false;

set_request_timer(Tmo, Op) ->
    erlang:start_timer(Tmo, self(), Op).

%%%-----------------------------------------------------------------

cancel_request_timer(false) ->
    ok;

cancel_request_timer(TRef) ->
    erlang:cancel_timer(TRef).

%%%-----------------------------------------------------------------

%% client_hello/1
%%
%% Prepend the 1.0 base capability only if none is specified by the
%% user. Store the versions in the process dictionary until they're
%% examined upon reception of server capabilities in handle_capx/1.

client_hello(Opts)
  when is_list(Opts) ->
    UserCaps = [{T, cap(lists:flatten(Cs))} || {capability = T, Cs} <- Opts],
    Vsns = versions(UserCaps),
    put(?KEY(protocol_vsn), Vsns),
    {hello,
     ?NETCONF_NAMESPACE_ATTR,
     [{capabilities, [{capability, [?NETCONF_BASE_CAP, ?NETCONF_BASE_CAP_VSN]}
                      || [] == Vsns]
                     ++ UserCaps}]}.

%% cap/1
%%
%% Let NETCONF capabilities be specified in the shorthand documented in
%% RFC 6241.

%% This shorthand is documented in RFC 6241 10.4 NETCONF Capabilities
%% URNS, but not in 8 Capabilities.
cap(":base:" ++ _ = Str) ->
    ["urn:ietf:params:netconf", Str];

cap([$:|_] = Str) ->
    ["urn:ietf:params:netconf:capability", Str];

cap(Str) ->
    [Str].

%% versions/1
%%
%% Extract base protocol versions from capability options.

versions(Opts) ->
    [V || {capability, L} <- Opts,
          S <- L,
          ?NETCONF_BASE_CAP ++ X <- [lists:flatten(S)],
          V <- [lists:takewhile(fun(C) -> C /= $? end, X)]].

%% handle_capx/1
%%
%% Ignore parameters as RFC 6241 (NETCONF 1.1) requires in 8.1
%% Capabilities Exchange. Be overly lenient with whitespace since RFC
%% 6241 gives examples with significant trailing whitespace.

handle_capx(#state{hello_status = received, capabilities = Caps} = S) ->
    Remote = [V || ?NETCONF_BASE_CAP ++ X <- Caps,
                   [V|_] <- [string:lexemes(X, "? \t\r\n")]],
    Local = erase(?KEY(protocol_vsn)),
    case protocol_vsn(Local, Remote) of
        false when Remote == [] ->
            Reason = {incorrect_hello, no_base_capability_found},
            {stop, {error, Reason}, S};
        false ->
            Reason = {incompatible_base_capability_vsn, lists:min(Remote)},
            {stop, {error, Reason}, S};
        Vsn ->
            put(?KEY(chunk), Vsn /= "1.0"),
            {reply, ok, rebuf(Vsn, S#state{hello_status = Vsn})}
    end;

handle_capx(#state{hello_status = {error, _} = No} = S) ->
    {stop, No, S}.

%% rebuf/2
%%
%% Turn the message buffer into a list for 1.1 chunking if the
%% negotiated protocol version is > 1.0.

rebuf("1.0", S) ->
    S;

rebuf(_, #state{buf = Bin} = S) ->
    S#state{buf = [Bin, 3]}.

%% protocol_vsn/2

protocol_vsn([], Vsns) ->
    protocol_vsn(["1.0"], Vsns);

protocol_vsn(Local, Remote) ->
    lists:max([false | [V || V <- Remote, lists:member(V, Local)]]).

%%%-----------------------------------------------------------------

encode_rpc_operation(Lock,[Target]) when Lock==lock; Lock==unlock ->
    {Lock,[{target,[Target]}]};
encode_rpc_operation(get,[Filter]) ->
    {get,filter(Filter)};
encode_rpc_operation(get_config,[Source,Filter]) ->
    {'get-config',[{source,[Source]}] ++ filter(Filter)};
encode_rpc_operation(edit_config,[Target,Config,OptParams]) ->
    {'edit-config',[{target,[Target]}] ++ OptParams ++ [{config,Config}]};
encode_rpc_operation(delete_config,[Target]) ->
    {'delete-config',[{target,[Target]}]};
encode_rpc_operation(copy_config,[Target,Source]) ->
    {'copy-config',[{target,[Target]},{source,[Source]}]};
encode_rpc_operation(action,[Action]) ->
    {action,?ACTION_NAMESPACE_ATTR,[{data,[Action]}]};
encode_rpc_operation(kill_session,[SessionId]) ->
    {'kill-session',[{'session-id',[integer_to_list(SessionId)]}]};
encode_rpc_operation(close_session,[]) ->
    'close-session';
encode_rpc_operation({create_subscription,_},
		     [Stream,Filter,StartTime,StopTime]) ->
    {'create-subscription',?NETCONF_NOTIF_NAMESPACE_ATTR,
     [{stream,[Stream]}] ++
	 filter(Filter) ++
	 maybe_element(startTime,StartTime) ++
	 maybe_element(stopTime,StopTime)}.

filter(undefined) ->
    [];
filter({xpath,Filter}) when ?is_string(Filter) ->
    [{filter,[{type,"xpath"},{select, Filter}],[]}];
filter(Filter) when is_list(Filter) ->
    [{filter,[{type,"subtree"}],Filter}];
filter(Filter) ->
    filter([Filter]).

maybe_element(_,undefined) ->
    [];
maybe_element(Tag,Value) ->
    [{Tag,[Value]}].

%%%-----------------------------------------------------------------
%%% Send XML data to server
do_send_rpc(Op, SimpleXml, Timeout, Caller, #state{connection = Connection,
                                                   msg_id = MsgId,
                                                   pending = Pending}
                                            = State) ->
    Msg = {rpc,
           [{'message-id', MsgId} | ?NETCONF_NAMESPACE_ATTR],
           [SimpleXml]},
    Next = MsgId + 1,
    case do_send(Connection, Msg) of
        ok ->
            TRef = set_request_timer(Timeout, Op),
            Rec = #pending{tref = TRef,
                           msg_id = MsgId,
                           op = Op,
                           caller = Caller},
            {noreply, State#state{msg_id = Next,
                                  pending = [Rec | Pending]}};
        Error ->
            {reply, Error, State#state{msg_id = Next}}
    end.

do_send(Connection, Simple) ->
    ssh_send(Connection, frame(to_xml(Simple))).

to_xml(Simple) ->
    Prolog = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    Chars = xmerl:export_simple([Simple],
                                xmerl_xml,
                                [#xmlAttribute{name = prolog,
                                               value = Prolog}]),
    unicode:characters_to_binary(Chars).

%% frame/1

frame(Bin) ->
    case get(?KEY(chunk)) of
        true ->  %% 1.1 chunking
            [chunk(Bin) | "\n##\n"];
        _ ->     %% 1.0 framing
            [Bin | ?END_TAG]
    end.

%% chunk/1
%%
%% Chunk randomly to exercise the server.

chunk(<<>>) ->
    [];

chunk(Bin) when is_binary(Bin) ->
    Sz = min(rand:uniform(1024), byte_size(Bin)),
    <<B:Sz/binary, Rest/binary>> = Bin,
    ["\n#", integer_to_list(Sz), $\n, B | chunk(Rest)].

%%%-----------------------------------------------------------------
%%% Parse and handle received XML data

handle_data(Bin, #state{buf = Head} = S) ->
    case recv(Bin, Head) of
        {error, Reason} ->
            Conn = S#state.connection,
            ?error(Conn#connection.name, [{receive_error, Reason},
                                          {buffer, Head},
                                          {bytes, Bin}]),
            {stop, S};
        {Bytes, Rest} ->
            handle_more(Rest, handle_xml(Bytes, S));
        Buf ->
            {noreply, S#state{buf = Buf}}
    end.

%% handle_more/2

handle_more(_, {stop, _} = No) ->
    No;

handle_more(Bin, {noreply, State}) ->
    handle_data(Bin, State#state{buf = true == get(?KEY(chunk))}).

%% handle_xml/2

handle_xml(Bytes, State) ->
    case parse(Bytes) of
        {ok, Simple, _Rest} ->  %% ignore trailing bytes
            decode(Simple, State);
        {fatal_error,_Loc,Reason,_EndTags,_EventState} ->
            Conn = State#state.connection,
            ?error(Conn#connection.name, [{parse_error, Reason},
                                          {message, Bytes}]),
            {noreply, handle_error(Reason, State)}
    end.

%% parse/1

parse(Bytes) ->
    xmerl_sax_parser:stream(<<>>, [{event_fun, fun sax_event/3},
                                   {event_state, []},
                                   {continuation_fun, fun cont/1},
                                   {continuation_state, Bytes}]).

%% cont/1

cont([] = No) ->
    {<<>>, No};

cont([Bin | Rest]) ->
    {Bin, Rest};

cont(Bin) ->
    {Bin, <<>>}.

%% handle_error/2

handle_error(_Reason, #state{pending = []} = State) ->
    State;

handle_error(Reason, #state{pending = Pending} = State) ->
    %% Assuming the first request gets the first answer.
    Rec = #pending{tref = TRef,
                   caller = Caller}
        = lists:last(Pending),
    cancel_request_timer(TRef),
    ct_gen_conn:return(Caller,{error, {failed_to_parse_received_data, Reason}}),
    State#state{pending = lists:delete(Rec, Pending)}.

%% Event function for the sax parser. It builds a simple XML structure.
%% Care is taken to keep namespace attributes and prefixes as in the original XML.
sax_event(Event,_Loc,State) ->
    sax_event(Event,State).

sax_event({startPrefixMapping, Prefix, Uri},Acc) ->
    %% startPrefixMapping will always come immediately before the
    %% startElement where the namespace is defined.
    [{xmlns,{Prefix,Uri}}|Acc];
sax_event({startElement,_Uri,_Name,QN,Attrs},Acc) ->
    %% Pick out any namespace attributes inserted due to a
    %% startPrefixMapping event.The rest of Acc will then be only
    %% elements.
    {NsAttrs,NewAcc} = split_attrs_and_elements(Acc,[]),
    Tag = qn_to_tag(QN),
    [{Tag,NsAttrs ++ parse_attrs(Attrs),[]}|NewAcc];
sax_event({endElement,_Uri,_Name,_QN},[{Name,Attrs,Cont},{Parent,PA,PC}|Acc]) ->
    [{Parent,PA,[{Name,Attrs,lists:reverse(Cont)}|PC]}|Acc];
sax_event(endDocument,[{Tag,Attrs,Cont}]) ->
    {Tag,Attrs,lists:reverse(Cont)};
sax_event({characters,String},[{Name,Attrs,Cont}|Acc]) ->
    [{Name,Attrs,[String|Cont]}|Acc];
sax_event(_Event,State) ->
    State.

split_attrs_and_elements([{xmlns,{Prefix,Uri}}|Rest],Attrs) ->
    split_attrs_and_elements(Rest,[{xmlnstag(Prefix),Uri}|Attrs]);
split_attrs_and_elements(Elements,Attrs) ->
    {Attrs,Elements}.

xmlnstag([]) ->
    xmlns;
xmlnstag(Prefix) ->
    list_to_atom("xmlns:"++Prefix).

qn_to_tag({[],Name}) ->
    list_to_atom(Name);
qn_to_tag({Prefix,Name}) ->
    list_to_atom(Prefix ++ ":" ++ Name).

parse_attrs([{_Uri, [], Name, Value}|Attrs]) ->
    [{list_to_atom(Name),Value}|parse_attrs(Attrs)];
parse_attrs([{_Uri, Prefix, Name, Value}|Attrs]) ->
    [{list_to_atom(Prefix ++ ":" ++ Name),Value}|parse_attrs(Attrs)];
parse_attrs([]) ->
    [].


%%%-----------------------------------------------------------------

%% decode/2
%%
%% Decode parsed (incoming) XML.

decode({Tag, _, _} = E, #state{} = State) ->
    case decode(get_local_name_atom(Tag), E, State) of
        #state{} = S ->
            {noreply, S};
        {stop, #state{}} = T ->
            T
    end.

%% decode/3

decode('rpc-reply', {_, Attrs, _} = E, State) ->
    decode_rpc_reply(get_msg_id(Attrs), E, State);

%% Incoming hello, outgoing not yet sent.
decode(hello, E, #state{hello_status = undefined} = State) ->
    case decode_hello(E) of
        {ok, SessionId, Capabilities} ->
            State#state{session_id = SessionId,
                        capabilities = Capabilities,
                        hello_status = received};
        {error, _Reason} = No ->
            State#state{hello_status = No}
    end;

%% Incoming hello, outgoing already sent: negotiate protocol version.
decode(hello, E, #state{hello_status = #pending{tref = TRef,
                                                caller = From}}
                 = State) ->
    cancel_request_timer(TRef),
    case decode_hello(E) of
        {ok, SessionId, Capabilities} ->
            reply(From, handle_capx(State#state{session_id = SessionId,
                                                capabilities = Capabilities,
                                                hello_status = received}));
        {error, _Reason} = No ->
            ct_gen_conn:return(From, No),
            {stop, State#state{hello_status = No}}
    end;

%% Duplicate hello: ignore.
decode(hello, E, #state{hello_status = Other} = State) ->
    ConnName = (State#state.connection)#connection.name,
    ?error(ConnName, [{got_unexpected_hello, E},
                      {hello_status, Other}]),
    State;

decode(notification, E, State) ->
    notify(State, E),
    State;

decode(Other, E, State) ->
    decode_send({got_unexpected_msg, Other}, E, State).

%% notify/2

notify(#state{receivers = []} = State, E) ->
    Name = (State#state.connection)#connection.name,
    ?error(Name, [{got_unexpected_notification, E}]);

%% Sending can fail with an atom-valued destination, but it's up to
%% the user.
notify(#state{receivers = T}, E) ->
    lists:foreach(fun(D) -> D ! E end, if is_pid(T) -> [T]; true -> T end).

%% reply/2
%%
%% Explicitly send a reply that can't be returned.

reply(From, {T, Res, State}) ->
    ct_gen_conn:return(From, Res),
    case T of
        reply ->
            State;
        stop ->
            {T, State}
    end.

%% get_msg_id/1

get_msg_id(Attrs) ->
    case find('message-id', Attrs) of
        {_,Str} ->
            list_to_integer(Str);
        false ->
            undefined
    end.

%% recode_rpc_reply/3

decode_rpc_reply(undefined, E, #state{pending = [#pending{msg_id = MsgId}]}
                               = State)
  when MsgId /= undefined ->
    ConnName = (State#state.connection)#connection.name,
    ?error(ConnName, [{warning, rpc_reply_missing_msg_id},
                      {assuming, MsgId}]),
    decode_rpc_reply(MsgId, E, State);

decode_rpc_reply(undefined, _, State) ->
    ConnName = (State#state.connection)#connection.name,
    ?error(ConnName, [{error, rpc_reply_missing_msg_id}]),
    State;

decode_rpc_reply(MsgId,
                 {_, Attrs, Content0}
                 = E,
                 #state{pending = Pending}
                 = State) ->
    case lists:keytake(MsgId, #pending.msg_id, Pending) of
        {value, Rec, Rest} ->
            #pending{tref = TRef, op = Op, caller = From}
                = Rec,
            cancel_request_timer(TRef),
            Content = forward_xmlns_attr(Attrs, Content0),
            {Reply, T} = do_decode_rpc_reply(Op,
                                             Content,
                                             State#state{pending = Rest}),
            ct_gen_conn:return(From, Reply),
            T;
        false ->  %% not a send_rcp or server has sent wrong id
            decode_send({got_unexpected_msg_id, MsgId}, E, State)
    end.

%% decode_send/2
%%
%% Result of send/2,3. Only handle one at a time there since all
%% pendings have msg_id = undefined.

decode_send(ErrorT, Elem, #state{pending = Pending} = State) ->
    case [P || #pending{msg_id = undefined} = P <- Pending] of
        [Rec] ->
            #pending{tref = TRef,
                     caller = From}
                = Rec,
            cancel_request_timer(TRef),
            ct_gen_conn:return(From, Elem),
            State#state{pending = lists:delete(Rec, Pending)};
        _ ->
            Conn = State#state.connection,
            ?error(Conn#connection.name, [ErrorT, {expecting, Pending}]),
            State
    end.

%% do_decode_rpc_reply/3

do_decode_rpc_reply(Op, Result, State)
  when Op == lock;
       Op == unlock;
       Op == edit_config;
       Op == delete_config;
       Op == copy_config;
       Op == kill_session ->
    {decode_ok(Result), State};

do_decode_rpc_reply(Op, Result, State)
  when Op == get;
       Op == get_config;
       Op == action ->
    {decode_data(Result), State};

do_decode_rpc_reply(close_session, Result, State) ->
    case decode_ok(Result) of
        ok ->
            {ok, {stop, State}};
        Other ->
            {Other, State}
    end;

%% Only set a new destination if one (or more) hasn't been set with a
%% receiver option(), to allow more than calls to create_subscription
%% to order notifications.
do_decode_rpc_reply({create_subscription, Pid}, Result, #state{receivers = T}
                                                        = State) ->
    case decode_ok(Result) of
        ok when T == [];
                is_pid(T) ->
            {ok, State#state{receivers = Pid}};
        Other ->
            {Other, State}
    end;

do_decode_rpc_reply(get_event_streams, Result, State) ->
    {decode_streams(decode_data(Result)), State};

do_decode_rpc_reply(undefined, Result, State) ->
    {Result, State}.



decode_ok([{Tag,Attrs,Content}]) ->
    case get_local_name_atom(Tag) of
	ok ->
	    ok;
	'rpc-error' ->
	    {error,forward_xmlns_attr(Attrs,Content)};
	_Other ->
	    {error,{unexpected_rpc_reply,[{Tag,Attrs,Content}]}}
    end;
decode_ok(Other) ->
    {error,{unexpected_rpc_reply,Other}}.

decode_data([{Tag,Attrs,Content}]) ->
    case get_local_name_atom(Tag) of
	ok ->
	    %% when action has return type void
	    ok;
	data ->
	    %% Since content of data has nothing from the netconf
	    %% namespace, we remove the parent's xmlns attribute here
	    %% - just to make the result cleaner
	    {ok,forward_xmlns_attr(remove_xmlnsattr_for_tag(Tag,Attrs),Content)};
	'rpc-error' ->
	    {error,forward_xmlns_attr(Attrs,Content)};
	_Other ->
	    {error,{unexpected_rpc_reply,[{Tag,Attrs,Content}]}}
    end;
decode_data(Other) ->
    {error,{unexpected_rpc_reply,Other}}.

get_qualified_name(Tag) ->
    case string:lexemes(atom_to_list(Tag),":") of
	[TagStr] -> {[],TagStr};
	[PrefixStr,TagStr] -> {PrefixStr,TagStr}
    end.

get_local_name_atom(Tag) ->
    {_,TagStr} = get_qualified_name(Tag),
    list_to_atom(TagStr).


%% Remove the xmlns attr that points to the tag. I.e. if the tag has a
%% prefix, remove {'xmlns:prefix',_}, else remove default {xmlns,_}.
remove_xmlnsattr_for_tag(Tag,Attrs) ->
    {Prefix,_TagStr} = get_qualified_name(Tag),
    lists:keydelete(xmlnstag(Prefix), 1, Attrs).

%% Prepend xmlns attributes from parent to children, omitting those
%% the child sets.
forward_xmlns_attr(ParentAttrs, Children) ->
    Namespace = lists:filter(fun is_xmlns/1, ParentAttrs),
    [{T, Ns ++ A, C} || {T, A, C} <- Children,
                        F <- [fun({K,_}) -> not lists:keymember(K, 1, A) end],
                        Ns <- [lists:filter(F, Namespace)]].

is_xmlns({Key, _}) ->
    Key == xmlns orelse lists:prefix("xmlns:", atom_to_list(Key)).

%% Decode server hello to pick out session id and capabilities
decode_hello({hello, _Attrs, Hello}) ->
    U = make_ref(),
    try
        [{'session-id', _, [SessionId]}, _ | _]
            = [find('session-id', Hello), no_session_id_found | U],
        [{ok, Id}, _ | _]
            = [catch {ok, list_to_integer(SessionId)}, invalid_session_id | U],
        [true, _ | _]
            = [0 < Id, invalid_session_id | U],
        [{capabilities, _, Capabilities}, _ | _]
            = [find(capabilities, Hello), capabilities_not_found | U],
        [{ok, Caps}, _ | _]
            = [decode_caps(Capabilities, [], false), false | U],
        {ok, Id, Caps}
    catch
        error: {badmatch, [Error, false | U]} ->
            Error;
        error: {badmatch, [_, Reason | U]} ->
            {error, {incorrect_hello, Reason}}
    end.

find(Key, List) ->
    lists:keyfind(Key, 1, List).

decode_caps([{capability, [], [?NETCONF_BASE_CAP ++ _ = Cap]} | Caps],
            Acc,
            _) ->
    decode_caps(Caps, [Cap|Acc], true);
decode_caps([{capability, [], [Cap]} | Caps], Acc, Base) ->
    decode_caps(Caps, [Cap|Acc], Base);
decode_caps([H|_], _, _) ->
    {error, {unexpected_capability_element, H}};
decode_caps([], _, false) ->
    {error, {incorrect_hello, no_base_capability_found}};
decode_caps([], Acc, true) ->
    {ok, lists:reverse(Acc)}.


%% Return a list of {Name,Data}, where data is a {Tag,Value} list for each stream
decode_streams({error,Reason}) ->
    {error,Reason};
decode_streams({ok,[{netconf,_,Streams}]}) ->
    {ok,decode_streams(Streams)};
decode_streams([{streams,_,Streams}]) ->
    decode_streams(Streams);
decode_streams([{stream,_,Stream} | Streams]) ->
    {name,_,[Name]} = find(name, Stream),
    [{Name,[{Tag,Value} || {Tag,_,[Value]} <- Stream, Tag /= name]}
     | decode_streams(Streams)];
decode_streams([]) ->
    [].


%%%-----------------------------------------------------------------
%%% Logging

log(Connection,Action) ->
    log(Connection,Action,<<>>).
log(#connection{reference=Ref,host=Host,port=Port,name=Name},Action,Data) ->
    Address =
        case Ref of
            {_,Ch} -> {Host,Port,Ch};
            _ -> {Host,Port}
        end,
    error_logger:info_report(#conn_log{client=self(),
				       address=Address,
				       name=Name,
				       action=Action,
				       module=?MODULE},
			     Data).


%% Log callback - called from the error handler process
-doc false.
format_data(How,Data) ->
    %% Assuming that the data is encoded as UTF-8.  If it is not, then
    %% the printout might be wrong, but the format function will not
    %% crash!
    %% FIXME: should probably read encoding from the data and do
    %% unicode:characters_to_binary(Data,InEncoding,utf8) when calling
    %% log/3 instead of assuming utf8 in as done here!
    do_format_data(How,unicode:characters_to_binary(Data)).

do_format_data(raw,Data) ->
    io_lib:format("~n~ts~n",[hide_password(Data)]);
do_format_data(pretty,Data) ->
    maybe_io_lib_format(indent(Data));
do_format_data(html,Data) ->
    maybe_io_lib_format(html_format(Data)).

maybe_io_lib_format(<<>>) ->
    [];
maybe_io_lib_format(String) ->
    io_lib:format("~n~ts~n",[String]).

%%%-----------------------------------------------------------------
%%% Hide password elements from XML data
hide_password(Bin) ->
    re:replace(Bin,<<"(<password[^>]*>)[^<]*(</password>)">>,<<"\\1*****\\2">>,
	       [global,{return,binary},unicode]).

%%%-----------------------------------------------------------------
%%% HTML formatting
html_format(Bin) ->
    binary:replace(indent(Bin),<<"<">>,<<"&lt;">>,[global]).

%%%-----------------------------------------------------------------
%%% Indentation of XML code
indent(Bin) ->
    String = normalize(hide_password(Bin)),
    IndentedString =
	case erase(part_of_line) of
	    undefined ->
		indent1(String,[]);
	    Part ->
		indent1(lists:reverse(Part)++String,erase(indent))
	end,
    unicode:characters_to_binary(IndentedString).

%% Normalizes the XML document by removing all space and newline
%% between two XML tags.
%% Returns a list, no matter if the input was a list or a binary.
normalize(Bin) ->
    re:replace(Bin,<<">[ \r\n\t]+<">>,<<"><">>,[global,{return,list},unicode]).


indent1("<?"++Rest1,Indent1) ->
    %% Prolog
    {Line,Rest2,Indent2} = indent_line(Rest1,Indent1,[$?,$<]),
    Line++indent1(Rest2,Indent2);
indent1("</"++Rest1,Indent1) ->
    %% Stop tag
    case indent_line1(Rest1,Indent1,[$/,$<]) of
	{[],[],_} ->
	    [];
	{Line,Rest2,Indent2} ->
	    "\n"++Line++indent1(Rest2,Indent2)
    end;
indent1("<"++Rest1,Indent1) ->
    %% Start- or empty tag
    put(tag,get_tag(Rest1)),
    case indent_line(Rest1,Indent1,[$<]) of
	{[],[],_} ->
	    [];
	{Line,Rest2,Indent2} ->
	    "\n"++Line++indent1(Rest2,Indent2)
    end;
indent1([H|T],Indent) ->
    [H|indent1(T,Indent)];
indent1([],_Indent) ->
    [].

indent_line("?>"++Rest,Indent,Line) ->
    %% Prolog
    {lists:reverse(Line)++"?>",Rest,Indent};
indent_line("/></"++Rest,Indent,Line) ->
    %% Empty tag, and stop of parent tag -> one step out in indentation
    {Indent++lists:reverse(Line)++"/>","</"++Rest,Indent--"  "};
indent_line("/>"++Rest,Indent,Line) ->
    %% Empty tag, then probably next tag -> keep indentation
    {Indent++lists:reverse(Line)++"/>",Rest,Indent};
indent_line("></"++Rest,Indent,Line) ->
    LastTag = erase(tag),
    case get_tag(Rest) of
	LastTag ->
	    %% Start and stop tag, but no content
	    indent_line1(Rest,Indent,[$/,$<,$>|Line]);
	_ ->
	    %% Stop tag completed, and then stop tag of parent -> one step out
	    {Indent++lists:reverse(Line)++">","</"++Rest,Indent--"  "}
    end;
indent_line("><"++Rest,Indent,Line) ->
    %% Stop tag completed, and new tag coming -> keep indentation
    {Indent++lists:reverse(Line)++">","<"++Rest,"  "++Indent};
indent_line("</"++Rest,Indent,Line) ->
    %% Stop tag starting -> search for end of this tag
    indent_line1(Rest,Indent,[$/,$<|Line]);
indent_line([H|T],Indent,Line) ->
    indent_line(T,Indent,[H|Line]);
indent_line([],Indent,Line) ->
    %% The line is not complete - will be continued later
    put(part_of_line,Line),
    put(indent,Indent),
    {[],[],Indent}.

indent_line1("></"++Rest,Indent,Line) ->
    %% Stop tag completed, and then stop tag of parent -> one step out
    {Indent++lists:reverse(Line)++">","</"++Rest,Indent--"  "};
indent_line1(">"++Rest,Indent,Line) ->
    %% Stop tag completed -> keep indentation
    {Indent++lists:reverse(Line)++">",Rest,Indent};
indent_line1([H|T],Indent,Line) ->
    indent_line1(T,Indent,[H|Line]);
indent_line1([],Indent,Line) ->
    %% The line is not complete - will be continued later
    put(part_of_line,Line),
    put(indent,Indent),
    {[],[],Indent}.

get_tag("/>"++_) ->
    [];
get_tag(">"++_) ->
    [];
get_tag([H|T]) ->
    [H|get_tag(T)];
get_tag([]) ->
    %% The line is not complete - will be continued later.
    [].


%%%-----------------------------------------------------------------
%%% SSH stuff
ssh_connect(#options{host=Host,timeout=Timeout,port=Port,
                     ssh=SshOpts,name=Name,type=Type}) ->
    case ssh:connect(Host, Port,
		     [{user_interaction,false},
		      {silently_accept_hosts, true}|SshOpts],
                     Timeout) of
	{ok,CM} ->
            Connection = #connection{reference = CM,
                                     host = Host,
                                     port = Port,
                                     name = Name,
                                     type = Type},
            log(Connection,connect),
            {ok,Connection};
	{error,Reason} ->
	    {error,{ssh,could_not_connect_to_server,Reason}}
    end.

ssh_channel(#connection{reference=CM}=Connection0,
            #options{timeout=Timeout,name=Name,type=Type}) ->
    case ssh_connection:session_channel(CM, Timeout) of
        {ok,Ch} ->
            case ssh_connection:subsystem(CM, Ch, "netconf", Timeout) of
                success ->
                    Connection = Connection0#connection{reference = {CM,Ch},
                                                       name = Name,
                                                       type = Type},
                    log(Connection,open),
                    {ok, Connection};
                failure ->
                    ssh_connection:close(CM,Ch),
                    {error,{ssh,could_not_execute_netconf_subsystem}};
                {error,timeout} ->
                    ssh_connection:close(CM,Ch),
                    {error,{ssh,could_not_execute_netconf_subsystem,timeout}}
            end;
        {error, Reason} ->
            {error,{ssh,could_not_open_channel,Reason}}
    end.


ssh_open(Options) ->
    case ssh_connect(Options) of
        {ok,Connection} ->
            case ssh_channel(Connection,Options) of
                {ok,_} = Ok ->
                    Ok;
                Error ->
                    ssh_close(Connection),
                    Error
            end;
        Error ->
            Error
    end.

ssh_send(#connection{reference = {CM,Ch}}=Connection, Data) ->
    case ssh_connection:send(CM, Ch, Data) of
	ok ->
            log(Connection,send,Data),
            ok;
	{error,Reason} ->
            {error,{ssh,failed_to_send_data,Reason}}
    end.

ssh_close(Connection=#connection{reference = {CM,Ch}, type = Type}) ->
    _ = ssh_connection:close(CM,Ch),
    log(Connection,close),
    case Type of
        connection_and_channel ->
            ssh_close(Connection#connection{reference = CM});
        _ ->
            ok
    end,
    ok;
ssh_close(Connection=#connection{reference = CM}) ->
    _ = ssh:close(CM),
    log(Connection,disconnect),
    ok.

%% ===========================================================================

%% recv/1
%%
%% Extract incoming messages using either NETCONF 1.0 framing or
%% NETCONF 1.1 chunking.

recv(Bin, true) ->
    recv(Bin, [<<>>, 3]);
recv(Bin, false) ->
    recv(Bin, <<>>);

recv(Bin, [Head, Len | Chunks]) ->       %% 1.1 chunking
    chunk(<<Head/binary, Bin/binary>>, Chunks, Len);

%% Start looking for the terminating end-of-message sequence ]]>]]>
%% 5 characters from the end of the buffered head, since this binary
%% has already been scanned.
recv(Bin, Head) when is_binary(Head) ->  %% 1.0 framing
    frame(<<Head/binary, Bin/binary>>, max(0, byte_size(Head) - 5)).

%% frame/2
%%
%% Extract a message terminated by the ]]>]]> end-of-message sequence.
%% Don't need to extract characters as UTF-8 since matching byte-wise
%% is unambiguous: the high-order bit of every byte of a multi-byte
%% UTF character is 1, while the end-of-message sequence is ASCII.

frame(Bin, Start) when is_binary(Bin) ->
    Sz = byte_size(Bin),
    Scope = {Start, Sz - Start},
    case binary:match(Bin, pattern(), [{scope, Scope}]) of
        {Len, 6} ->
            <<Msg:Len/binary, _:6/binary, Rest/binary>> = Bin,
            {trim(Msg), Rest};
        nomatch ->
            Bin
    end.

%% pattern/0

pattern() ->
    Key = ?KEY(pattern),
    case get(Key) of
        undefined ->
            CP = binary:compile_pattern(<<"]]>]]>">>),
            put(Key, CP),
            CP;
        CP ->
            CP
    end.

%% trim/1
%%
%% Whitespace before an XML declaration is an error, but be somewhat
%% lenient and strip line breaks since the RFC's are unclear on what's
%% allowed following a ]]>]]> delimiter. Typical seems to be a single
%% $\n, but strip any of " \t\r\n", and regardless of NETCONF version.

trim(<<C, Bin/binary>>)
  when C == $\n;
       C == $\r;
       C == $\t;
       C == $  ->
    trim(Bin);

trim(Bin) ->
    Bin.

%% chunk/3
%%
%% The final argument is either 0 to indicate that a specified number
%% of bytes of chunk data should be consumed, or at least 3 to
%% indicate an offset at which to look for a newline following a chunk
%% size.

%% Accumulating chunk-data ...
chunk(Bin, [Sz | Chunks] = L, 0) ->
    case Bin of
        <<Chunk:Sz/binary, Rest/binary>> ->
            chunk(Rest, acc(Chunk, Chunks), 3);  %% complete chunk ...
        _ ->
            [Bin, 0 | L]                         %% ... or not
    end;

%% ... or a header.

chunk(Bin, Chunks, Len)
  when byte_size(Bin) < 4 ->
    [Bin, 3 = Len | Chunks];

%% End of chunks.
chunk(<<"\n##\n", Rest/binary>>, Chunks, _) ->
    case Chunks of
        [] ->
            {error, "end-of-chunks unexpected"}; %% must be at least one
        Bins ->
            {lists:reverse(Bins), Rest}
    end;

%% Matching each of the 10 newline possibilities is faster than
%% searching.
chunk(<<"\n#", Head:1/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:2/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:3/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:4/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:5/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:6/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:7/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:8/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:9/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);
chunk(<<"\n#", Head:10/binary, $\n, Rest/binary>>, Chunks, _) ->
    acc(Head, Rest, Chunks);

chunk(<<"\n#", Bin:11/binary, _/binary>>, _, _) ->
    {error, {"chunk-size too long", Bin}}; %% 32-bits = max 10 digits

chunk(<<"\n#", _/binary>> = Bin, Chunks, _) ->
    [Bin, byte_size(Bin) | Chunks];

chunk(Bin, Chunks, 3 = Len) ->
    case drop(Bin) of
        <<>> ->
            [Bin, Len | Chunks];
        <<"\n#", _/binary>> = B ->
            chunk(B, Chunks, Len);
        _ ->
            {error, {"not a chunk", Bin}}
    end.

%% drop/1

drop(<<"\n#", _/binary>> = Bin) ->
    Bin;

drop(<<C, Bin/binary>>)
  when C == $\n;
       C == $\r;
       C == $\t;
       C == $  ->
    drop(Bin);

drop(Bin) ->
    Bin.

%% acc/2

acc(Chunk, []) ->
    [B || B <- [trim(Chunk)], <<>> /= B];

acc(Chunk, Chunks) ->
    [Chunk | Chunks].

%% acc/3

acc(Head, Rest, Chunks) ->
    case chunk_size(Head) of
        {error, _Reason} = No ->
            No;
        Sz ->
            chunk(Rest, [Sz | Chunks], 0)
    end.

%% chunk_size/1

chunk_size(<<C, _/binary>> = Bin) ->
    try true = $0 < C, binary_to_integer(Bin) of
        Sz when 0 < Sz bsr 32 ->
            {error, {"chunk-size too large", Sz}};
        Sz ->
            Sz
    catch
        error: _ ->
            {error, {"chunk-size invalid", Bin}}
    end.

%%----------------------------------------------------------------------
%% END OF MODULE
%%----------------------------------------------------------------------
