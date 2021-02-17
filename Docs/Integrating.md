# Integrating Gordian Cosigner

Gordian Cosigner is meant to be used with a wallet that can initiate PSBT transactions, or some other transaction coordinator service. Following are documents on using it with other services.

## Using Bitcoin Core to Support GCS

Perhaps the best way to use Gordian Cosigner with Bitcoin Core is to fully create your keys and accounts in other systems, such as **Gordian Wallet** and **Gordian Cosigner**, but then to take advantage of the full-node capabilities of Bitcoin Core to Initiate and Finalize transactions. Following is a description of how to do so.

### Creating a Descriptor for Bitcoin Core

To do any work on existing cosigners or accounts in Bitcoin Core requires creating a descriptor that Bitcoin Core will be able to understand. This should be a `wsh(sortmulti` descriptor, to match the methodology of **Gordian Cosigner**. There are two ways to create this descriptor: you can either export the "descriptor" from the **Accounts** tab of **Gordian Cosigner**, or you can export the individual origins and public keys from the **Cosigners** tab and build a complete descriptor on your own. 

Once you have creating a proper descriptor, you'll be able to use it for a variety of functions on Bitcoin Core.

#### Creating a Descriptor from Accounts Information

The export function on the **Accounts** tab in **Gordian Cosigner** will produce text like the following:
```
{"blockheight":0,"descriptor":"wsh(sortedmulti(2,[a890879a\/48h\/1h\/0h\/2h]tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83,[90081696\/48h\/1h\/0h\/2h]tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1))","label":"2 of 2"}
```
To use that descriptor with Bitcoin Core, you must do the following:

1. Extract the "descriptor"
2. Remove the backslashes ("\"s).
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
Your final descriptor for use with Bitcoin Core should be the `descriptor` with checksum output by `getdescriptorinfo`.
```
$ multi_desc_with_cs="wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))#clyps7au"
```
#### Creating a Descriptor from Cosigners Information

Alternatively, you have everything you need in the **Cosigners** tab. You can go to each individual cosigner and incorporate all of that information to create your descriptor by hand.

For example, look at the "Cosigner Detailer" for the first cosigner above and tap the "Text" button, which will give you an `xpub` that Bitcoin Core can understand:
```
Origin:

a890879a/48h/1h/0h/2h

Public key:

tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83
```
You'll need to repeat this for each cosigner. You can then pull together a complete descriptor as follows, using the example of this 2-of-2 multisig:
```
wsh(sortedmulti($M,[$ORIGIN1],$PUBKEY1/0/*,[$ORIGIN2],$PUBKEY2/0/*))#$CS
```
Where:

* $M is the required number of sigs
* $ORIGINX is the origin for the Xth cosigner
* $PUBKEYX is the pubkey for the Xth cosigner
* /0/* is the range for the main addresses
* $CS is the checksub derived by `getdescriptorinfo`

This should generate the same descriptor as created by **Gordian Cosigner**, but this methodology allows you to create it from the individual keys on your own.
```
wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))
```
From here, checksum the descriptor as above.
```
$ bitcoin-cli getdescriptorinfo $multi_desc
{
  "descriptor": "wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))#clyps7au",
  "checksum": "hym8n9jx",
  "isrange": true,
  "issolvable": true,
  "hasprivatekeys": false
}
```

### Testing Addresses on Bitcoin Core

With a descriptor with checksum in hand, you can now use it for functions in Bitcoin Core. One thing that you can do is derive addresses, so that you can check your addresses in **Gordian Cosigner** against another service. All that requires is the `deriveaddresses` RPC call in `bitcoin-cli`:
```
multi_desc_with_cs="wsh(sortedmulti(2,[a890879a/48'/1'/0'/2']tpubDEzcZKQ5N3ymDtUv6ekeyiESkAr5BwKSFdL4afXDDLf2f7KhJ5cyr2XrKqHwYutxYEVoUcDxdTFM2qPvvr1nwaa7HtAeJN4b4RuGRhPSS83/0/*,[90081696/48'/1'/0'/2']tpubDFhpmpiYsqtknPaom1M3hDM17gm4UPhCbjqj33k27tGf1bHWMcfyuNPLYozB1uzaaYyFz3CxJU7wzBdQ1FiRSfMaftbUYHgMZ5SrV5FcxV1/0/*))#clyps7au"
$ bitcoin-cli deriveaddresses $multi_desc_with_cs [0,10]
[
  "tb1q64xk7lxyccmr77ulr82a7zvxq8radpmhk9hgsx85qwks88lqcyzsk489k6",
  "tb1q6t8d35rzry92s3xeaa27hsglgu5s4j6pr9fsxzvpu2f7le0mf5dqapjnhx",
  "tb1qp4whlnjheen73ul5ewc6h9trw27zjvquaxc2glmjwnmwyv47xs6qcfnq7d",
  "tb1qr99x5gffuhhe59cef3m2dkhqwz4zq793czg4xr8xck8872uup8tq8ueaz9",
  "tb1qlerjd5uuhk29yry4uc5p8dte262ay4uhnc0yqmwe56pj8umec6nshn9x8n",
  "tb1qm6t7kzfdh2tza9mv4w8klmla35f5tmt0ye2p7kl2f4jl728jw9vqa7hduj",
  "tb1qrrc9s66x6f67ppn54fprfjz7jkh9m5pe24rj498e5f9lmpshyu9snxpe8d",
  "tb1q7dl555ch6k327dkkqmg7dxky89d7yny3xqvmz88rcngmjz2prt3s94u65r",
  "tb1qcvtajx33fek50y5ghcv5tl525fqkhz0zlgp7hu98hjl2x0eyy5eqk58jhd",
  "tb1qzqeuf7yva0dv4vqsrmflnvqxl538mtvdt4fsd97j0k7net86vwwqcruvzz",
  "tb1q00deke3cfsp224clld5ea3denrcdemsz7ey3x668urguy04hkzsqmjf8cv"
]
```
You can compare these in **Gordian Cosigner** by going to the **Accounts** tab, clicking the account in question and choosing "Address Explorer". Just click through the first few receive addresses; they should match the first few Bitcoin Core derived addresses.

### Importing An Account into Bitcoin Core

If you'd like to make Bitcoin Core a fully functional part of your **Gordian Cosigner** ecosystem, you can do so by creating a Bitcoin Core wallet that contains watchonly copies of your multisig account addresses.

You should start off creating a new wallet:
```
$bitcoin-cli createwallet  "test" true true
```
This creates a wallet called `test` without private keys (that's the first `true`) and with no keys of its own (that's the second `true`).

You can then import your addresses using the descriptor.
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
Note: this imports just 100 addresses. You might want more in the future, but for best safety you should import a limited number at any time.

### Creating PSBTs on Bitcoin Core

Once you've set Bitcoin Core up as a watch-only wallet for your multisig account, you can also use it to be a transaction coordinator, acting as an Initiator for your multisigs.

One of the easiest ways to create a PSBT is with `walletcreatefundedpsbt` (but see [Learning Bitcoin from the Command Line §7.1](https://github.com/BlockchainCommons/Learning-Bitcoin-from-the-Command-Line/blob/master/07_1_Creating_a_Partially_Signed_Bitcoin_Transaction.md) for more options). To use it you'll need a change address, which you have to create by hand because of the lack of keys in your wallet. You might use another address from your wallet. (Here, the change address is set to `$change` and a recipient is set as `$recipient`).

With your change address in hand, it's easy to run `walletcreatefundedpsbt`:
```
$ bitcoin-cli -rpcwallet=test -named walletcreatefundedpsbt inputs='''[]''' outputs='''{ "'$recipient'": 0.004 }''' options='''{ "changeAddress": "'$change'"}'''

{
  "psbt": "cHNidP8BAH0CAAAAASzqXxsYmidrIEKpa8KAvxNkejcofDJxVl+gWbhwl9UMAQAAAAD+////AuuFAQAAAAAAIgAgxbXR3sHtW9YuS5gtxziS3dVjkTtpou0FzE8X7pcGluWAGgYAAAAAABYAFK/W8cQ72pyoz6C/mPike31NWH2JAAAAAAABASsgoQcAAAAAACIAINVNb3zExjY/e58Z1d8JhgHH1od3sW6IGPQDrQOf4MEFAQVHUiECzgv0MLMTc2kivaKIAY0HCjtkwQvfmyHwaohJfvLtRdEhAzN+W+0uqIIlN0HgB7M1Ht4kugmwXe32Pdfm6MOg0m9oUq4iBgLOC/QwsxNzaSK9oogBjQcKO2TBC9+bIfBqiEl+8u1F0RyokIeaMAAAgAEAAIAAAACAAgAAgAAAAAAAAAAAIgYDM35b7S6ogiU3QeAHszUe3iS6CbBd7fY91+bow6DSb2gckAgWljAAAIABAACAAAAAgAIAAIAAAAAAAAAAAAABAUdSIQKxOzcdmNl6+F+bVu7Y4nVIzqratVycnfu9k/3akm/rFCEDCgsPnBjIgl/6pLaUpUg3FUi4Cs3fCPokQRCASIxH0B1SriICArE7Nx2Y2Xr4X5tW7tjidUjOqtq1XJyd+72T/dqSb+sUHJAIFpYwAACAAQAAgAAAAIACAACAAQAAACgAAAAiAgMKCw+cGMiCX/qktpSlSDcVSLgKzd8I+iRBEIBIjEfQHRyokIeaMAAAgAEAAIAAAACAAgAAgAEAAAAoAAAAAAA=",
  "fee": 0.00000181,
  "changepos": 0
}
```
This sends 0.004 BTC to the `$recipient`. Bitcoin Core figures out how to collect the funds and makes sure your change goes back to `$change`.

Here's what that PSBT looks like:
```
$ fundedpsbt="cHNidP8BAH0CAAAAASzqXxsYmidrIEKpa8KAvxNkejcofDJxVl+gWbhwl9UMAQAAAAD+////AuuFAQAAAAAAIgAgxbXR3sHtW9YuS5gtxziS3dVjkTtpou0FzE8X7pcGluWAGgYAAAAAABYAFK/W8cQ72pyoz6C/mPike31NWH2JAAAAAAABASsgoQcAAAAAACIAINVNb3zExjY/e58Z1d8JhgHH1od3sW6IGPQDrQOf4MEFAQVHUiECzgv0MLMTc2kivaKIAY0HCjtkwQvfmyHwaohJfvLtRdEhAzN+W+0uqIIlN0HgB7M1Ht4kugmwXe32Pdfm6MOg0m9oUq4iBgLOC/QwsxNzaSK9oogBjQcKO2TBC9+bIfBqiEl+8u1F0RyokIeaMAAAgAEAAIAAAACAAgAAgAAAAAAAAAAAIgYDM35b7S6ogiU3QeAHszUe3iS6CbBd7fY91+bow6DSb2gckAgWljAAAIABAACAAAAAgAIAAIAAAAAAAAAAAAABAUdSIQKxOzcdmNl6+F+bVu7Y4nVIzqratVycnfu9k/3akm/rFCEDCgsPnBjIgl/6pLaUpUg3FUi4Cs3fCPokQRCASIxH0B1SriICArE7Nx2Y2Xr4X5tW7tjidUjOqtq1XJyd+72T/dqSb+sUHJAIFpYwAACAAQAAgAAAAIACAACAAQAAACgAAAAiAgMKCw+cGMiCX/qktpSlSDcVSLgKzd8I+iRBEIBIjEfQHRyokIeaMAAAgAEAAIAAAACAAgAAgAEAAAAoAAAAAAA="
$ bitcoin-cli analyzepsbt $fundedpsbt
{
  "inputs": [
    {
      "has_utxo": true,
      "is_final": false,
      "next": "signer",
      "missing": {
        "signatures": [
          "f36c33cbe30ee2b37d97602b21be732593e7e18f",
          "54b6c0b13c28bebfe9a74858d4a6e2da15f759e4"
        ]
      }
    }
  ],
  "estimated_vsize": 180,
  "estimated_feerate": 0.00001005,
  "fee": 0.00000181,
  "next": "signer"
}
```
As the `analyze` shows, all the data is there, all you're missing is the `signer`. That's the state that a PSBT needs to be in when you send it to **Gordian Cosigner**.

Here's what that PSBT looks like in detail:
```
standup@btctest:~$ bitcoin-cli decodepsbt $fundedpsbt
{
  "tx": {
    "txid": "a967ae537eebc3222ed591e47eb951790ad16a72706bfc17b2ac482fd9c7901f",
    "hash": "a967ae537eebc3222ed591e47eb951790ad16a72706bfc17b2ac482fd9c7901f",
    "version": 2,
    "size": 125,
    "vsize": 125,
    "weight": 500,
    "locktime": 0,
    "vin": [
      {
        "txid": "0cd59770b859a05f5671327c28377a6413bf80c26ba942206b279a181b5fea2c",
        "vout": 1,
        "scriptSig": {
          "asm": "",
          "hex": ""
        },
        "sequence": 4294967294
      }
    ],
    "vout": [
      {
        "value": 0.00099819,
        "n": 0,
        "scriptPubKey": {
          "asm": "0 c5b5d1dec1ed5bd62e4b982dc73892ddd563913b69a2ed05cc4f17ee970696e5",
          "hex": "0020c5b5d1dec1ed5bd62e4b982dc73892ddd563913b69a2ed05cc4f17ee970696e5",
          "reqSigs": 1,
          "type": "witness_v0_scripthash",
          "addresses": [
            "tb1qck6arhkpa4davtjtnqkuwwyjmh2k8yfmdx3w6pwvfut7a9cxjmjsyanm92"
          ]
        }
      },
      {
        "value": 0.00400000,
        "n": 1,
        "scriptPubKey": {
          "asm": "0 afd6f1c43bda9ca8cfa0bf98f8a47b7d4d587d89",
          "hex": "0014afd6f1c43bda9ca8cfa0bf98f8a47b7d4d587d89",
          "reqSigs": 1,
          "type": "witness_v0_keyhash",
          "addresses": [
            "tb1q4lt0r3pmm2w23naqh7v03frm04x4slvf4dmhzn"
          ]
        }
      }
    ]
  },
  "unknown": {
  },
  "inputs": [
    {
      "witness_utxo": {
        "amount": 0.00500000,
        "scriptPubKey": {
          "asm": "0 d54d6f7cc4c6363f7b9f19d5df098601c7d68777b16e8818f403ad039fe0c105",
          "hex": "0020d54d6f7cc4c6363f7b9f19d5df098601c7d68777b16e8818f403ad039fe0c105",
          "type": "witness_v0_scripthash",
          "address": "tb1q64xk7lxyccmr77ulr82a7zvxq8radpmhk9hgsx85qwks88lqcyzsk489k6"
        }
      },
      "witness_script": {
        "asm": "2 02ce0bf430b313736922bda288018d070a3b64c10bdf9b21f06a88497ef2ed45d1 03337e5bed2ea882253741e007b3351ede24ba09b05dedf63dd7e6e8c3a0d26f68 2 OP_CHECKMULTISIG",
        "hex": "522102ce0bf430b313736922bda288018d070a3b64c10bdf9b21f06a88497ef2ed45d12103337e5bed2ea882253741e007b3351ede24ba09b05dedf63dd7e6e8c3a0d26f6852ae",
        "type": "multisig"
      },
      "bip32_derivs": [
        {
          "pubkey": "02ce0bf430b313736922bda288018d070a3b64c10bdf9b21f06a88497ef2ed45d1",
          "master_fingerprint": "a890879a",
          "path": "m/48'/1'/0'/2'/0/0"
        },
        {
          "pubkey": "03337e5bed2ea882253741e007b3351ede24ba09b05dedf63dd7e6e8c3a0d26f68",
          "master_fingerprint": "90081696",
          "path": "m/48'/1'/0'/2'/0/0"
        }
      ]
    }
  ],
  "outputs": [
    {
      "witness_script": {
        "asm": "2 02b13b371d98d97af85f9b56eed8e27548ceaadab55c9c9dfbbd93fdda926feb14 030a0b0f9c18c8825ffaa4b694a548371548b80acddf08fa24411080488c47d01d 2 OP_CHECKMULTISIG",
        "hex": "522102b13b371d98d97af85f9b56eed8e27548ceaadab55c9c9dfbbd93fdda926feb1421030a0b0f9c18c8825ffaa4b694a548371548b80acddf08fa24411080488c47d01d52ae",
        "type": "multisig"
      },
      "bip32_derivs": [
        {
          "pubkey": "02b13b371d98d97af85f9b56eed8e27548ceaadab55c9c9dfbbd93fdda926feb14",
          "master_fingerprint": "90081696",
          "path": "m/48'/1'/0'/2'/1/40"
        },
        {
          "pubkey": "030a0b0f9c18c8825ffaa4b694a548371548b80acddf08fa24411080488c47d01d",
          "master_fingerprint": "a890879a",
          "path": "m/48'/1'/0'/2'/1/40"
        }
      ]
    },
    {
    }
  ],
  "fee": 0.00000181
}
```
At this point you can go to the **Payments** tab in **Gordian Cosigner** and import this PSBT, and then you'll be given the opportunity to sign it.

### Finalizing PSBTs on Bitcoin Core

Any networked wallet can send out the PSBT once everyone has signed it. Here's how to do it with your Bitcoin Core instance once you've been sent a final PSBT.

First, test and make sure it's ready to go:
```
$ signed_psbt="cHNidP8BAH0CAAAAASzqXxsYmidrIEKpa8KAvxNkejcofDJxVl+gWbhwl9UMAQAAAAD+////AuuFAQAAAAAAIgAgxbXR3sHtW9YuS5gtxziS3dVjkTtpou0FzE8X7pcGluWAGgYAAAAAABYAFK/W8cQ72pyoz6C/mPike31NWH2JAAAAAAABASsgoQcAAAAAACIAINVNb3zExjY/e58Z1d8JhgHH1od3sW6IGPQDrQOf4MEFIgICzgv0MLMTc2kivaKIAY0HCjtkwQvfmyHwaohJfvLtRdFHMEQCIF1kPb/AU3d6waVIvD4tNZJop+bYHtQSgQjtd+nrH9AAAiBixzMBCUlLNGVQ7a8RK5GtkN1U+tkXWHhl9Pq1wWE55wEiAgMzflvtLqiCJTdB4AezNR7eJLoJsF3t9j3X5ujDoNJvaEgwRQIhAMAZ1iP0mEN5AIcmm7KAeJEHzmt3EB9VcZemtfcfFUiPAiBeK2znNKTVTJbvfULvggrEWyMO3hZlLbAF2cz4by/RsAEBBUdSIQLOC/QwsxNzaSK9oogBjQcKO2TBC9+bIfBqiEl+8u1F0SEDM35b7S6ogiU3QeAHszUe3iS6CbBd7fY91+bow6DSb2hSriIGAs4L9DCzE3NpIr2iiAGNBwo7ZMEL35sh8GqISX7y7UXRHKiQh5owAACAAQAAgAAAAIACAACAAAAAAAAAAAAiBgMzflvtLqiCJTdB4AezNR7eJLoJsF3t9j3X5ujDoNJvaByQCBaWMAAAgAEAAIAAAACAAgAAgAAAAAAAAAAAAAEBR1IhArE7Nx2Y2Xr4X5tW7tjidUjOqtq1XJyd+72T/dqSb+sUIQMKCw+cGMiCX/qktpSlSDcVSLgKzd8I+iRBEIBIjEfQHVKuIgICsTs3HZjZevhfm1bu2OJ1SM6q2rVcnJ37vZP92pJv6xQckAgWljAAAIABAACAAAAAgAIAAIABAAAAKAAAACICAwoLD5wYyIJf+qS2lKVINxVIuArN3wj6JEEQgEiMR9AdHKiQh5owAACAAQAAgAAAAIACAACAAQAAACgAAAAAAA=="
$ bitcoin-cli analyzepsbt $signed_psbt
{
  "inputs": [
    {
      "has_utxo": true,
      "is_final": false,
      "next": "finalizer"
    }
  ],
  "estimated_vsize": 181,
  "estimated_feerate": 0.00001000,
  "fee": 0.00000181,
  "next": "finalizer"
}
```
Then, finalize it:
```
$ bitcoin-cli finalizepsbt $signed_psbt
{
  "hex": "020000000001012cea5f1b189a276b2042a96bc280bf13647a37287c3271565fa059b87097d50c0100000000feffffff02eb85010000000000220020c5b5d1dec1ed5bd62e4b982dc73892ddd563913b69a2ed05cc4f17ee970696e5801a060000000000160014afd6f1c43bda9ca8cfa0bf98f8a47b7d4d587d89040047304402205d643dbfc053777ac1a548bc3e2d359268a7e6d81ed4128108ed77e9eb1fd000022062c7330109494b346550edaf112b91ad90dd54fad917587865f4fab5c16139e701483045022100c019d623f49843790087269bb280789107ce6b77101f557197a6b5f71f15488f02205e2b6ce734a4d54c96ef7d42ef820ac45b230ede16652db005d9ccf86f2fd1b00147522102ce0bf430b313736922bda288018d070a3b64c10bdf9b21f06a88497ef2ed45d12103337e5bed2ea882253741e007b3351ede24ba09b05dedf63dd7e6e8c3a0d26f6852ae00000000",
  "complete": true
}
```
And you can use the hex to send:
```
$ bitcoin-cli sendrawtransaction "020000000001012cea5f1b189a276b2042a96bc280bf13647a37287c3271565fa059b87097d50c0100000000feffffff02eb85010000000000220020c5b5d1dec1ed5bd62e4b982dc73892ddd563913b69a2ed05cc4f17ee970696e5801a060000000000160014afd6f1c43bda9ca8cfa0bf98f8a47b7d4d587d89040047304402205d643dbfc053777ac1a548bc3e2d359268a7e6d81ed4128108ed77e9eb1fd000022062c7330109494b346550edaf112b91ad90dd54fad917587865f4fab5c16139e701483045022100c019d623f49843790087269bb280789107ce6b77101f557197a6b5f71f15488f02205e2b6ce734a4d54c96ef7d42ef820ac45b230ede16652db005d9ccf86f2fd1b00147522102ce0bf430b313736922bda288018d070a3b64c10bdf9b21f06a88497ef2ed45d12103337e5bed2ea882253741e007b3351ede24ba09b05dedf63dd7e6e8c3a0d26f6852ae00000000"a967ae537eebc3222ed591e47eb951790ad16a72706bfc17b2ac482fd9c7901f
```
Congratulations, you've finished the round-trip for a multisig PSBT, using **Gordian Cosigner** and Bitcoin Core.
