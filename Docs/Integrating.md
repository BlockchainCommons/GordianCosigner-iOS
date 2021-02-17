# Integrating Gordian Cosigner

Gordian Cosigner is meant to be used with a wallet that can initiate PSBT transactions, or some other transaction coordinator service. Following are documents on using it with other services.

## Using GCS with Bitcoin Core

To create an account in Bitcoin Core that matches your multisig in **Gordian Cosigner** requires creating a `wsh(sortmulti` descriptor. There are two ways to do this: you can either export the "descriptor" from the **Accounts** tab, or you can export the individual origins and public keys from the **Cosigners** tab and build a complete descriptor on your own.

### Exporting from Accounts

The export function on the **Accounts** tab will produce text like the following:
```
{"blockheight":0,"descriptor":"wsh(sortedmulti(2,[a890879a\/48h\/1h\/0h\/2h]tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83,[90081696\/48h\/1h\/0h\/2h]tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1))","label":"2 of 2"}
```
To use it with Bitcoin Core, you must do the following:

1. Extract the "descriptor"
2. Remove the backslashes "\"s.
3. Range each of the two xpubs with `/0/*`, for main addresses, or `/1/*` for change addresses.

This should produce something like the following:
```
wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))
```

4. Use `getdescriptorinfo` to checksum your descriptor

```
$ multi_desc="wsh(sortedmulti(2,[a890879a/48h/1h/0h/2h]tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48h/1h/0h/2h]tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))"
$ bitcoin-cli getdescriptorinfo $multi_desc
{
  "descriptor": "wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))#clyps7au",
  "checksum": "hym8n9jx",
  "isrange": true,
  "issolvable": true,
  "hasprivatekeys": false
}
```

5. Use the modified and checksummed descriptor with any `bitcoin-cli` functions

```
multi_desc_with_cs="wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))#clyps7au"
```
At that point, you can check your addresses like this:
```
$ bitcoin-cli deriveaddresses $multi_desc_with_cs [0,10]
```
And even import individual addresses if you like.

If you prefer to import a range of address, you can create a new wallet:
```
$bitcoin-cli createwallet  "test" true true
```
And do so:
```
$ bitcoin-cli -rpcwallet=test importmulti '[{"desc": "'$multi_desc_with_cs'", "timestamp": "now", "range": 100}]'
[
  {
    "success": true,
    "warnings": [
      "Some private keys are missing, outputs will be considered watchonly. If this is intentional, specify the watchonly flag."
    ]
  }
]
```

### Exporting from Cosigners

Alternatively, you have everything you need in the **Cosigners** tab. You can go to each individual cosigner and incorporate all of that information to create your descriptor.

For example, the "Cosigner Detailer" for the first cosigner above, when you view the "Text" that Bitcoin Core can understand lists:

```
Origin:

a890879a/48h/1h/0h/2h

Public key:

tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83
```
You can put together your own descriptor as follows, using the example of this 2-of-2 multisig:
```
wsh(sortedmulti($M,[$ORIGIN1],$PUBKEY1/0/*,[$ORIGIN2],$PUBKEY2/0/*))#$CS
```
Where:

* $M is the required number of sigs
* $ORIGINX is the origin for the Xth cosigner
* $PUBKEYX is the pubkey for the Xth cosigner
* /0/* is the range for the main addresses
* $CS is the checksub derived by `getdescriptorinfo`

This should generate the same descriptor as created by **Gordian Cosigner**, but allows you to create it from the individual keys on your own.

