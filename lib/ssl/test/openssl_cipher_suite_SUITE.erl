%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2019-2025. All Rights Reserved.
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

%%

-module(openssl_cipher_suite_SUITE).

-include("ssl_test_lib.hrl").
-include_lib("common_test/include/ct.hrl").

%% Callback functions
-export([all/0,
         groups/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2]).

%% Testcases
-export([%%dhe_psk_des_cbc/1,
         dhe_rsa_3des_ede_cbc/1,
         dhe_rsa_aes_128_cbc/1,
         dhe_rsa_aes_128_gcm/1,
         dhe_rsa_aes_256_cbc/1,
         dhe_rsa_aes_256_gcm/1,
         dhe_rsa_chacha20_poly1305/1,
         ecdhe_rsa_3des_ede_cbc/1,
         ecdhe_rsa_rc4_128/1,
         ecdhe_rsa_aes_128_cbc/1,
         ecdhe_rsa_aes_128_gcm/1,
         ecdhe_rsa_aes_256_cbc/1,
         ecdhe_rsa_aes_256_gcm/1,
         ecdhe_rsa_chacha20_poly1305/1,
         ecdhe_ecdsa_rc4_128/1,
         ecdhe_ecdsa_3des_ede_cbc/1,
         ecdhe_ecdsa_aes_128_cbc/1,
         ecdhe_ecdsa_aes_128_gcm/1,
         ecdhe_ecdsa_aes_256_cbc/1,
         ecdhe_ecdsa_aes_256_gcm/1,
         ecdhe_ecdsa_chacha20_poly1305/1,
         rsa_des_cbc/1,
         rsa_3des_ede_cbc/1,
         rsa_aes_128_cbc/1,
         rsa_aes_256_cbc/1,
         rsa_aes_128_gcm/1,
         rsa_aes_256_gcm/1,
         rsa_rc4_128/1,
         dhe_dss_des_cbc/1,
         dhe_dss_3des_ede_cbc/1,
         dhe_dss_aes_128_cbc/1,
         dhe_dss_aes_256_cbc/1,
         dhe_dss_aes_128_gcm/1,
         dhe_dss_aes_256_gcm/1,
         dh_anon_rc4_128/1,
         dh_anon_3des_ede_cbc/1,
         dh_anon_aes_128_cbc/1,
         dh_anon_aes_128_gcm/1,
         dh_anon_aes_256_cbc/1,
         dh_anon_aes_256_gcm/1,
         ecdh_anon_3des_ede_cbc/1,
         ecdh_anon_aes_128_cbc/1,
         ecdh_anon_aes_256_cbc/1,
         aes_256_gcm_sha384/1,
         aes_128_gcm_sha256/1,
         chacha20_poly1305_sha256/1,
         aes_128_ccm_sha256/1,
         aes_128_ccm_8_sha256/1,
         ecdhe_ecdsa_with_aes_128_ccm/1,
         ecdhe_ecdsa_with_aes_256_ccm/1,
         ecdhe_ecdsa_with_aes_128_ccm_8/1,
         ecdhe_ecdsa_with_aes_256_ccm_8/1
        ]).

-define(DEFAULT_TIMEOUT, {seconds, 15}).

%%--------------------------------------------------------------------
%% Common Test interface functions -----------------------------------
%%--------------------------------------------------------------------
all() ->
    [{group,  openssl_server},
     {group,  openssl_client}].

all_protocol_groups() ->
    [
     {group, 'tlsv1.3'},
     {group, 'tlsv1.2'},
     {group, 'tlsv1.1'},
     {group, 'tlsv1'},
     {group, 'dtlsv1.2'},
     {group, 'dtlsv1'}
     ].

groups() ->
    %% TODO: Enable SRP, PSK suites (needs OpenSSL s_server conf)
    %% TODO: Enable all "kex" on DTLS
    [
     {openssl_server, all_protocol_groups()},
     {openssl_client, all_protocol_groups()},
     {'tlsv1.3', [parallel], tls_1_3_kex()},
     {'tlsv1.2', [], kex()},
     {'tlsv1.1', [], kex()},
     {'tlsv1', [], kex()},
     {'dtlsv1.2', [], dtls_kex()},
     {'dtlsv1', [], dtls_kex()},
     {dhe_rsa, [parallel],[dhe_rsa_3des_ede_cbc,
                   dhe_rsa_aes_128_cbc,
                   dhe_rsa_aes_128_gcm,
                   dhe_rsa_aes_256_cbc,
                   dhe_rsa_aes_256_gcm,
                   dhe_rsa_chacha20_poly1305
                  ]},
     {ecdhe_rsa, [parallel], [ecdhe_rsa_3des_ede_cbc,
                      ecdhe_rsa_rc4_128,
                      ecdhe_rsa_aes_128_cbc,
                      ecdhe_rsa_aes_128_gcm,
                      ecdhe_rsa_aes_256_cbc,
                      ecdhe_rsa_aes_256_gcm,
                      ecdhe_rsa_chacha20_poly1305
                    ]},
     {ecdhe_1_3_rsa_cert, [parallel], tls_1_3_cipher_suites()},
     {ecdhe_ecdsa, [parallel],[ecdhe_ecdsa_rc4_128,
                       ecdhe_ecdsa_3des_ede_cbc,
                       ecdhe_ecdsa_aes_128_cbc,
                       ecdhe_ecdsa_aes_128_gcm,
                       ecdhe_ecdsa_aes_256_cbc,
                       ecdhe_ecdsa_aes_256_gcm,
                       ecdhe_ecdsa_chacha20_poly1305,
                       ecdhe_ecdsa_with_aes_128_ccm,
                       ecdhe_ecdsa_with_aes_256_ccm,
                       ecdhe_ecdsa_with_aes_128_ccm_8,
                       ecdhe_ecdsa_with_aes_256_ccm_8
                      ]},
     {rsa, [parallel], [rsa_des_cbc,
                rsa_3des_ede_cbc,
                rsa_aes_128_cbc,
                rsa_aes_256_cbc,
                rsa_rc4_128
               ]},
     {dhe_dss, [parallel], [dhe_dss_3des_ede_cbc,
                    dhe_dss_aes_128_cbc,
                    dhe_dss_aes_256_cbc]},
     %% {srp_rsa, [], [srp_rsa_3des_ede_cbc,
     %%                srp_rsa_aes_128_cbc,
     %%                srp_rsa_aes_256_cbc]},
     %% {srp_dss, [], [srp_dss_3des_ede_cbc,
     %%                srp_dss_aes_128_cbc,
     %%                srp_dss_aes_256_cbc]},
     %% {rsa_psk, [], [rsa_psk_3des_ede_cbc,
     %%                rsa_psk_rc4_128,
     %%                rsa_psk_aes_128_cbc,
     %%                rsa_psk_aes_256_cbc
     %%               ]},
     {dh_anon, [parallel], [dh_anon_rc4_128,
                    dh_anon_3des_ede_cbc,
                    dh_anon_aes_128_cbc,
                    dh_anon_aes_128_gcm,
                    dh_anon_aes_256_cbc,
                    dh_anon_aes_256_gcm]},
     {ecdh_anon, [parallel], [ecdh_anon_3des_ede_cbc,
                      ecdh_anon_aes_128_cbc,
                      ecdh_anon_aes_256_cbc
                     ]}
     %% {srp_anon, [], [srp_anon_3des_ede_cbc,
     %%                 srp_anon_aes_128_cbc,
     %%                 srp_anon_aes_256_cbc]},
     %% {psk, [], [psk_3des_ede_cbc,
     %%            psk_rc4_128,
     %%            psk_aes_128_cbc,
     %%            psk_aes_128_ccm,
     %%            psk_aes_128_ccm_8,
     %%            psk_aes_256_cbc,
     %%            psk_aes_256_ccm,
     %%            psk_aes_256_ccm_8
     %%           ]},
     %% {dhe_psk, [], [dhe_psk_3des_ede_cbc,
     %%                dhe_psk_rc4_128,
     %%                dhe_psk_aes_128_cbc,
     %%                dhe_psk_aes_128_ccm,
     %%                dhe_psk_aes_128_ccm_8,
     %%                dhe_psk_aes_256_cbc,
     %%                dhe_psk_aes_256_ccm,
     %%                dhe_psk_aes_256_ccm_8
     %%           ]},
     %% {ecdhe_psk, [], [ecdhe_psk_3des_ede_cbc,
     %%                 ecdhe_psk_rc4_128,
     %%                 ecdhe_psk_aes_128_cbc,
     %%                 ecdhe_psk_aes_128_ccm,
     %%                 ecdhe_psk_aes_128_ccm_8,
     %%                 ecdhe_psk_aes_256_cbc
     %%           ]}
    ].
tls_1_3_kex() ->
    [{group, ecdhe_1_3_rsa_cert}].

tls_1_3_cipher_suites() ->
    [aes_256_gcm_sha384,
     aes_128_gcm_sha256,
     chacha20_poly1305_sha256,
     aes_128_ccm_sha256,
     aes_128_ccm_8_sha256
    ].

kex() ->
     rsa() ++ ecdsa() ++ dss() ++ anonymous().

dtls_kex() -> %% Should be all kex in the future
      dtls_rsa() ++ dss() ++ anonymous().

rsa() ->
    [{group, dhe_rsa},
     {group, ecdhe_rsa},
     {group, rsa} %%, {group, srp_rsa},
     %%{group, rsa_psk}
    ].

dtls_rsa() ->
    [
     {group, rsa}
     %%,{group, rsa_psk}
    ].

ecdsa() ->
    [{group, ecdhe_ecdsa}].

dss() ->
    [{group, dhe_dss}
     %%{group, srp_dss}
    ].

anonymous() ->
    [{group, dh_anon},
     {group, ecdh_anon}
     %% {group, psk},
     %%{group, dhe_psk},
     %%{group, ecdhe_psk}
     %%{group, srp_anon}
    ].

init_per_suite(Config) ->
    ssl_test_lib:init_per_suite(Config, openssl).

end_per_suite(Config) ->
    ssl_test_lib:end_per_suite(Config).

%%--------------------------------------------------------------------
init_per_group(GroupName, Config) ->
    case ssl_test_lib:working_openssl_client(Config) of
        false when GroupName =:= openssl_client ->
            throw({skip, "Ignore non-working openssl_client"});
        _ -> ok
    end,
    case ssl_test_lib:is_protocol_version(GroupName) of
        true ->
            ssl_test_lib:init_per_group_openssl(GroupName, Config);
        false ->
            do_init_per_group(GroupName, Config)
    end.

do_init_per_group(openssl_client, Config0) ->
    Config = proplists:delete(server_type, proplists:delete(client_type, Config0)),
    [{client_type, openssl}, {server_type, erlang} | Config];
do_init_per_group(openssl_server, Config0) ->
    Config = proplists:delete(server_type, proplists:delete(client_type, Config0)),
    [{client_type, erlang}, {server_type, openssl} | Config];
do_init_per_group(GroupName, Config) when GroupName == ecdh_anon;
                                       GroupName == ecdhe_rsa;
                                       GroupName == ecdhe_psk;
                                       GroupName ==  ecdhe_1_3_rsa_cert->
    case proplists:get_bool(ecdh, proplists:get_value(public_keys, crypto:supports())) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing EC crypto support"}
    end;
do_init_per_group(ecdhe_ecdsa = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(ecdh, PKAlg) andalso lists:member(ecdsa, PKAlg) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing EC crypto support"}
    end;
do_init_per_group(dhe_dss = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(dss, PKAlg) andalso lists:member(dh, PKAlg)
        andalso (ssl_test_lib:openssl_dsa_suites() =/= []) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing DSS crypto support"}
    end;
do_init_per_group(srp_dss = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(dss, PKAlg) andalso lists:member(srp, PKAlg)
        andalso (ssl_test_lib:openssl_dsa_suites() =/= []) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing DSS_SRP crypto support"}
    end;
do_init_per_group(GroupName, Config) when GroupName == srp_anon;
                                          GroupName == srp_rsa ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(srp, PKAlg) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing SRP crypto support"}
    end;
do_init_per_group(dhe_psk = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(dh, PKAlg) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing SRP crypto support"}
    end;
do_init_per_group(dhe_rsa = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(dh, PKAlg) andalso lists:member(rsa, PKAlg) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing SRP crypto support"}
    end;
do_init_per_group(rsa = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(rsa, PKAlg) andalso ssl_test_lib:openssl_support_rsa_kex() of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing RSA key exchange support"}
    end;
do_init_per_group(dh_anon = GroupName, Config) ->
    PKAlg = proplists:get_value(public_keys, crypto:supports()),
    case lists:member(dh, PKAlg) of
        true ->
            init_certs(GroupName, Config);
        false ->
            {skip, "Missing SRP crypto support"}
    end.

end_per_group(GroupName, Config) ->
    ssl_test_lib:end_per_group(GroupName, Config).

init_per_testcase(TestCase, Config) when TestCase == psk_3des_ede_cbc;
                                         TestCase == srp_anon_3des_ede_cbc;
                                         TestCase == dhe_psk_3des_ede_cbc;
                                         TestCase == ecdhe_psk_3des_ede_cbc;
                                         TestCase == srp_rsa_3des_ede_cbc;
                                         TestCase == srp_dss_3des_ede_cbc;
                                         TestCase == rsa_psk_3des_ede_cbc;
                                         TestCase == rsa_3des_ede_cbc;
                                         TestCase == dhe_rsa_3des_ede_cbc;
                                         TestCase == dhe_dss_3des_ede_cbc;
                                         TestCase == ecdhe_rsa_3des_ede_cbc;
                                         TestCase == srp_anon_dss_3des_ede_cbc;
                                         TestCase == dh_anon_3des_ede_cbc;
                                         TestCase == ecdh_anon_3des_ede_cbc;
                                         TestCase == ecdhe_ecdsa_3des_ede_cbc ->
    SupCiphers = proplists:get_value(ciphers, crypto:supports()),
    case lists:member(des_ede3_cbc, SupCiphers) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing 3DES crypto support"}
    end;
init_per_testcase(TestCase, Config) when TestCase == psk_rc4_128;
                                         TestCase == ecdhe_psk_rc4_128;
                                         TestCase == dhe_psk_rc4_128;
                                         TestCase == rsa_psk_rc4_128;
                                         TestCase == rsa_rc4_128;
                                         TestCase == ecdhe_rsa_rc4_128;
                                         TestCase == ecdhe_ecdsa_rc4_128;
                                         TestCase == dh_anon_rc4_128 ->
    case supported_cipher(rc4, "RC4") of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing RC4 crypto support"}
    end;
init_per_testcase(TestCase, Config) when  TestCase == psk_aes_128_ccm_8;
                                          TestCase == psk_aes_128_ccm_8;
                                          TestCase == dhe_psk_aes_128_ccm_8;
                                          TestCase == ecdhe_psk_aes_128_ccm_8 ->
    case supported_cipher(aes_128_ccm, "AES128-CCM8") of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_128_CCM crypto support"}
    end;
init_per_testcase(TestCase, Config) when TestCase == psk_aes_256_ccm_8;
                                         TestCase == psk_aes_256_ccm_8;
                                         TestCase == dhe_psk_aes_256_ccm_8;
                                         TestCase == ecdhe_psk_aes_256_ccm_8 ->

    case supported_cipher(aes_256_ccm, "AES128-CCM8")  of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_256_CCM crypto support"}
    end;
init_per_testcase(aes_256_gcm_sha384, Config) ->
    case supported_cipher(aes_256_gcm, "AES_256_GCM", sha384) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_256_GCM crypto support"}
    end;
init_per_testcase(aes_128_gcm_sha256, Config) ->
    case  supported_cipher(aes_128_gcm, "AES_128_GCM", sha256) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_128_GCM crypto support"}
    end;

init_per_testcase(chacha20_poly1305_sha256, Config) ->
    case supported_cipher(chacha20_poly1305_sha256, "CHACHA20", sha256) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing CHACHA20_POLY1305 crypto support"}
    end;
init_per_testcase(aes_128_ccm_sha256, Config) ->
    case supported_cipher(aes_128_ccm, "AES_128_CCM", sha256) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_128_CCM crypto support"}
    end;

init_per_testcase(aes_128_ccm_8_sha256, Config) ->
    case supported_cipher(aes_128_ccm, "AES_128_CCM8", sha256) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_128_CCM_8 crypto support"}
    end;

init_per_testcase(TestCase, Config) when TestCase == ecdhe_ecdsa_with_aes_128_ccm;
                                         TestCase == ecdhe_ecdsa_with_aes_128_ccm_8->
    case supported_cipher(aes_128_ccm, "AES_128_CCM") of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_128_CCM crypto support"}
    end;

init_per_testcase(TestCase, Config) when TestCase == ecdhe_ecdsa_with_aes_256_ccm;
                                         TestCase == ecdhe_ecdsa_with_aes_256_ccm_8 ->

    case supported_cipher(aes_256_ccm, "AES256_CCM") of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, "Missing AES_256_CCM crypto support"}
    end;

init_per_testcase(TestCase, Config) ->
    Cipher = ssl_test_lib:test_cipher(TestCase, Config),
    SupCiphers = proplists:get_value(ciphers, crypto:supports()),
    case lists:member(Cipher, SupCiphers) of
        true ->
            ct:timetrap(?DEFAULT_TIMEOUT),
            Config;
        _ ->
            {skip, {Cipher, SupCiphers}}
    end.

end_per_testcase(_TestCase, Config) ->
    Config.

%%--------------------------------------------------------------------
%% Initializtion ------------------------------------------
%%--------------------------------------------------------------------
init_certs(srp_rsa, Config) ->
    {ClientOpts, ServerOpts} = ssl_test_lib:make_rsa_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, undefined}} | ServerOpts],
                    client_config => [{srp_identity, {"Test-User", "secret"}} | ClientOpts]}} |
     proplists:delete(tls_config, Config)];
init_certs(srp_anon, Config) ->
    [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, undefined}}],
                    client_config => [{srp_identity, {"Test-User", "secret"}}]}} |
     proplists:delete(tls_config, Config)];
init_certs(rsa_psk, Config) ->
    Ext = x509_test:extensions([{key_usage, [digitalSignature, keyEncipherment]}]),
    {ClientOpts, ServerOpts} = ssl_test_lib:make_rsa_cert_chains([{server_chain,
                                                                   [[ssl_test_lib:digest()],[ssl_test_lib:digest()],
                                                                    [ssl_test_lib:digest(), {extensions, Ext}]]},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, "_peer_keyEncipherment"),
    PskSharedSecret = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15>>,
    [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, PskSharedSecret}} | ServerOpts],
                    client_config => [{psk_identity, "Test-User"},
                                      {user_lookup_fun, {fun ssl_test_lib:user_lookup/3, PskSharedSecret}} | ClientOpts]}} |
     proplists:delete(tls_config, Config)];
init_certs(rsa, Config) ->
    Version = ssl_test_lib:n_version(proplists:get_value(version, Config)),
    SigAlgs = ssl_test_lib:sig_algs(rsa, Version),
    Ext = x509_test:extensions([{key_usage, [digitalSignature, keyEncipherment]}]),
    {ClientOpts, ServerOpts} = ssl_test_lib:make_rsa_cert_chains([{server_chain,
                                                                   [[ssl_test_lib:digest()],[ssl_test_lib:digest()],
                                                                    [ssl_test_lib:digest(), {extensions, Ext}]]}
                                                                 ],
                                                                 Config, "_peer_keyEncipherment"),
    [{tls_config, #{server_config => SigAlgs ++ ServerOpts,
                    client_config => SigAlgs ++ ClientOpts}} |
     proplists:delete(tls_config, Config)];
init_certs(dhe_dss, Config) ->
    Version = ssl_test_lib:n_version(proplists:get_value(version, Config)),
    SigAlgs = ssl_test_lib:sig_algs(dsa, Version),
    {ClientOpts, ServerOpts} = ssl_test_lib:make_dsa_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => SigAlgs ++ ServerOpts,
                    client_config => SigAlgs ++ClientOpts}} |
     proplists:delete(tls_config, Config)];
init_certs(srp_dss, Config) ->
    {ClientOpts, ServerOpts} = ssl_test_lib:make_dsa_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, undefined}} | ServerOpts],
                    client_config => [{srp_identity, {"Test-User", "secret"}} | ClientOpts]}} |
       proplists:delete(tls_config, Config)];
init_certs(GroupName, Config) when GroupName == dhe_rsa;
                                   GroupName == ecdhe_rsa ->
    {ClientOpts, ServerOpts} = ssl_test_lib:make_rsa_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => ServerOpts,
                    client_config => ClientOpts}} |
     proplists:delete(tls_config, Config)];
init_certs(ecdhe_1_3_rsa_cert, Config) ->
    {ClientOpts, ServerOpts} = ssl_test_lib:make_rsa_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                  {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => ServerOpts,
                    client_config => ClientOpts}} |
     proplists:delete(tls_config, Config)];


init_certs(GroupName, Config) when GroupName == dhe_ecdsa;
                                   GroupName == ecdhe_ecdsa ->
    {ClientOpts, ServerOpts} = ssl_test_lib:make_ecc_cert_chains([{server_chain, ssl_test_lib:default_cert_chain_conf()},
                                                                 {client_chain, ssl_test_lib:default_cert_chain_conf()}],
                                                                 Config, ""),
    [{tls_config, #{server_config => ServerOpts,
                    client_config => ClientOpts}} |
     proplists:delete(tls_config, Config)];
init_certs(GroupName, Config) when GroupName == psk;
                                   GroupName == dhe_psk;
                                   GroupName == ecdhe_psk ->
    PskSharedSecret = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15>>,
    [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, PskSharedSecret}}],
                    client_config => [{psk_identity, "Test-User"},
                                      {user_lookup_fun, {fun ssl_test_lib:user_lookup/3, PskSharedSecret}}]}} |
     proplists:delete(tls_config, Config)];
init_certs(srp, Config) ->
      [{tls_config, #{server_config => [{user_lookup_fun, {fun ssl_test_lib:user_lookup/3, undefined}}],
                      client_config => [{srp_identity, {"Test-User", "secret"}}]}} |
       proplists:delete(tls_config, Config)];
init_certs(_GroupName, Config) ->
    %% Anonymous does not need certs
     [{tls_config, #{server_config => [],
                     client_config => []}} |
       proplists:delete(tls_config, Config)].
%%--------------------------------------------------------------------
%% Test Cases --------------------------------------------------------
%%--------------------------------------------------------------------
aes_256_gcm_sha384(Config) when is_list(Config)->
    run_ciphers_test(ecdhe_rsa, 'aes_256_gcm', Config).

aes_128_gcm_sha256(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_128_gcm', Config).

chacha20_poly1305_sha256(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'chacha20_poly1305', Config).

aes_128_ccm_sha256(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_128_ccm', Config).

aes_128_ccm_8_sha256(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_128_ccm_8', Config).

%%--------------------------------------------------------------------
%% SRP --------------------------------------------------------
%%--------------------------------------------------------------------
%% srp_rsa_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(srp_rsa, '3des_ede_cbc', Config).

%% srp_rsa_aes_128_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_rsa, 'aes_128_cbc', Config).

%% srp_rsa_aes_256_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_rsa, 'aes_256_cbc', Config).

%% srp_dss_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(srp_dss, '3des_ede_cbc', Config).

%% srp_dss_aes_128_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_dss, 'aes_128_cbc', Config).

%% srp_dss_aes_256_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_dss, 'aes_256_cbc', Config).

%%--------------------------------------------------------------------
%% PSK --------------------------------------------------------
%%--------------------------------------------------------------------
%% rsa_psk_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(rsa_psk, '3des_ede_cbc', Config).

%% rsa_psk_aes_128_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(rsa_psk, 'aes_128_cbc', Config).

%% rsa_psk_aes_256_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(rsa_psk, 'aes_256_cbc', Config).

%% rsa_psk_rc4_128(Config) when is_list(Config) ->
%%     run_ciphers_test(rsa_psk, 'rc4_128', Config).

%%--------------------------------------------------------------------
%% RSA --------------------------------------------------------
%%--------------------------------------------------------------------
rsa_des_cbc(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'des_cbc', Config).

rsa_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(rsa, '3des_ede_cbc', Config).

rsa_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'aes_128_cbc', Config).

rsa_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'aes_256_cbc', Config).

rsa_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'aes_128_gcm', Config).

rsa_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'aes_256_gcm', Config).

rsa_rc4_128(Config) when is_list(Config) ->
    run_ciphers_test(rsa, 'rc4_128', Config).
%%--------------------------------------------------------------------
%% DHE_RSA --------------------------------------------------------
%%--------------------------------------------------------------------
dhe_rsa_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, '3des_ede_cbc', Config).

dhe_rsa_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, 'aes_128_cbc', Config).

dhe_rsa_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, 'aes_128_gcm', Config).

dhe_rsa_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, 'aes_256_cbc', Config).

dhe_rsa_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, 'aes_256_gcm', Config).

dhe_rsa_chacha20_poly1305(Config) when is_list(Config) ->
    run_ciphers_test(dhe_rsa, 'chacha20_poly1305', Config).
%%--------------------------------------------------------------------
%% ECDHE_RSA --------------------------------------------------------
%%--------------------------------------------------------------------
ecdhe_rsa_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, '3des_ede_cbc', Config).

ecdhe_rsa_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_128_cbc', Config).

ecdhe_rsa_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_128_gcm', Config).

ecdhe_rsa_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_256_cbc', Config).

ecdhe_rsa_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'aes_256_gcm', Config).

ecdhe_rsa_rc4_128(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'rc4_128', Config).

ecdhe_rsa_chacha20_poly1305(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_rsa, 'chacha20_poly1305', Config).

%%--------------------------------------------------------------------
%% ECDHE_ECDSA --------------------------------------------------------
%%--------------------------------------------------------------------
ecdhe_ecdsa_rc4_128(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'rc4_128', Config).

ecdhe_ecdsa_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, '3des_ede_cbc', Config).

ecdhe_ecdsa_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_128_cbc', Config).

ecdhe_ecdsa_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_128_gcm', Config).

ecdhe_ecdsa_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_256_cbc', Config).

ecdhe_ecdsa_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_256_gcm', Config).

ecdhe_ecdsa_chacha20_poly1305(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'chacha20_poly1305', Config).

ecdhe_ecdsa_with_aes_128_ccm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_128_ccm', Config).

ecdhe_ecdsa_with_aes_256_ccm(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_256_ccm', Config).

ecdhe_ecdsa_with_aes_128_ccm_8(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_128_ccm_8', Config).

ecdhe_ecdsa_with_aes_256_ccm_8(Config) when is_list(Config) ->
    run_ciphers_test(ecdhe_ecdsa, 'aes_256_ccm_8', Config).
%%--------------------------------------------------------------------
%% DHE_DSS --------------------------------------------------------
%%--------------------------------------------------------------------
dhe_dss_des_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, 'des_cbc', Config).

dhe_dss_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, '3des_ede_cbc', Config).

dhe_dss_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, 'aes_128_cbc', Config).

dhe_dss_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, 'aes_256_cbc', Config).

dhe_dss_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, 'aes_128_gcm', Config).

dhe_dss_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dhe_dss, 'aes_256_gcm', Config).

%%--------------------------------------------------------------------
%% Anonymous --------------------------------------------------------
%%--------------------------------------------------------------------
dh_anon_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, '3des_ede_cbc', Config).

dh_anon_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, 'aes_128_cbc', Config).

dh_anon_aes_128_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, 'aes_128_gcm', Config).

dh_anon_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, 'aes_256_cbc', Config).

dh_anon_aes_256_gcm(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, 'aes_256_gcm', Config).

dh_anon_rc4_128(Config) when is_list(Config) ->
    run_ciphers_test(dh_anon, 'rc4_128', Config).

ecdh_anon_3des_ede_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdh_anon, '3des_ede_cbc', Config).

ecdh_anon_aes_128_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdh_anon, 'aes_128_cbc', Config).

ecdh_anon_aes_256_cbc(Config) when is_list(Config) ->
    run_ciphers_test(ecdh_anon, 'aes_256_cbc', Config).

%% srp_anon_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(srp_anon, '3des_ede_cbc', Config).

%% srp_anon_aes_128_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_anon, 'aes_128_cbc', Config).

%% srp_anon_aes_256_cbc(Config) when is_list(Config) ->
%%    run_ciphers_test(srp_anon, 'aes_256_cbc', Config).

%% dhe_psk_des_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'des_cbc', Config).

%% dhe_psk_rc4_128(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'rc4_128', Config).

%% dhe_psk_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, '3des_ede_cbc', Config).

%% dhe_psk_aes_128_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_128_cbc', Config).

%% dhe_psk_aes_256_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_256_cbc', Config).

%% dhe_psk_aes_128_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_128_gcm', Config).

%% dhe_psk_aes_256_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_256_gcm', Config).

%% dhe_psk_aes_128_ccm(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_128_ccm', Config).

%% dhe_psk_aes_256_ccm(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_256_ccm', Config).

%% dhe_psk_aes_128_ccm_8(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_128_ccm_8', Config).

%% dhe_psk_aes_256_ccm_8(Config) when is_list(Config) ->
%%     run_ciphers_test(dhe_psk, 'aes_256_ccm_8', Config).

%% ecdhe_psk_des_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'des_cbc', Config).

%% ecdhe_psk_rc4_128(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'rc4_128', Config).

%% ecdhe_psk_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, '3des_ede_cbc', Config).

%% ecdhe_psk_aes_128_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_128_cbc', Config).

%% ecdhe_psk_aes_256_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_256_cbc', Config).

%% ecdhe_psk_aes_128_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_128_gcm', Config).

%% ecdhe_psk_aes_256_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_256_gcm', Config).

%% ecdhe_psk_aes_128_ccm(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_128_ccm', Config).

%% ecdhe_psk_aes_128_ccm_8(Config) when is_list(Config) ->
%%     run_ciphers_test(ecdhe_psk, 'aes_128_ccm_8', Config).

%% psk_des_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'des_cbc', Config).

%% psk_rc4_128(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'rc4_128', Config).

%% psk_3des_ede_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, '3des_ede_cbc', Config).

%% psk_aes_128_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_128_cbc', Config).

%% psk_aes_256_cbc(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_256_cbc', Config).

%% psk_aes_128_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_128_gcm', Config).

%% psk_aes_256_gcm(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_256_gcm', Config).

%% psk_aes_128_ccm(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_128_ccm', Config).

%% psk_aes_256_ccm(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_256_ccm', Config).

%% psk_aes_128_ccm_8(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_128_ccm_8', Config).

%% psk_aes_256_ccm_8(Config) when is_list(Config) ->
%%     run_ciphers_test(psk, 'aes_256_ccm_8', Config).

%%--------------------------------------------------------------------
%% Internal functions  ----------------------------------------------
%%--------------------------------------------------------------------
run_ciphers_test(Kex, Cipher, Config) ->
    Version = ssl_test_lib:protocol_version(Config),
    TestCiphers = test_ciphers(Kex, Cipher, Version),

    case TestCiphers of
        [_|_] ->
            lists:foreach(fun(TestCipher) ->
                                  cipher_suite_test(TestCipher, Version, Config)
                          end, TestCiphers);
        []  ->
            {skip, {not_sup, Kex, Cipher, Version}}
    end.

cipher_suite_test(CipherSuite, Version, Config) ->
    #{server_config := SOpts,
      client_config := COpts} = proplists:get_value(tls_config, Config),
    ServerOpts = ssl_test_lib:ssl_options(SOpts, Config),
    ClientOpts = ssl_test_lib:ssl_options(COpts, Config),
    ?CT_LOG("Testing CipherSuite ~p~n", [CipherSuite]),
    ?CT_LOG("Server Opts ~p~n", [ServerOpts]),
    ?CT_LOG("Client Opts ~p~n", [ClientOpts]),
    case proplists:get_value(server_type, Config) of
        erlang ->
            ssl_test_lib:basic_test([{ciphers, ssl:cipher_suites(all, Version)} | COpts],
                                    [{ciphers, [CipherSuite]} | SOpts], Config);
        _ ->
            ssl_test_lib:basic_test([{versions, [Version]}, {ciphers, [CipherSuite]} | COpts],
                                    [{ciphers,  ssl_test_lib:openssl_ciphers()} | SOpts], Config)
    end.

test_ciphers(Kex, Cipher, Version) ->
    Ciphers = ssl:filter_cipher_suites(ssl:cipher_suites(all, Version) ++ ssl:cipher_suites(anonymous, Version),
                                       [{key_exchange,
                                         fun(Kex0) when (Kex0 == Kex) andalso (Version =/= 'tlsv1.3') -> true;
                                            (Kex0) when (Kex0 == any) andalso (Version == 'tlsv1.3') -> true;
                                            (_) -> false
                                         end},
                                        {cipher,
                                         fun(Cipher0) when Cipher0 == Cipher -> true;
                                            (_) -> false
                                         end}]),
    ?CT_LOG("Version ~p Testing  ~p~n", [Version, Ciphers]),
    OpenSSLCiphers = ssl_test_lib:openssl_ciphers(),
    ?CT_LOG("OpenSSLCiphers ~p~n", [OpenSSLCiphers]),
    lists:filter(fun(C) ->
                         ?CT_LOG("Cipher ~p~n", [C]),
                         lists:member(ssl_cipher_format:suite_map_to_openssl_str(C), OpenSSLCiphers)
                 end, Ciphers).


supported_cipher(Cipher, CipherStr) ->
    SupCrypto = proplists:get_value(ciphers, crypto:supports()),
    SupOpenssl = [OCipher || OCipher <- ssl_test_lib:openssl_ciphers(),  string:find(OCipher, CipherStr) =/= nomatch],
    lists:member(Cipher, SupCrypto) andalso SupOpenssl =/= [].

supported_cipher(Cipher, CipherStr, Hash) ->
    Hashes = proplists:get_value(hashs, crypto:supports()),
    supported_cipher(Cipher, CipherStr) andalso lists:member(Hash, Hashes).
