# Gordian Cosigner User Scenarios

**Gordian Cosigner** is an application that creates multisignature accounts to ensure the [#SmartCustody](https://www.smartcustody.com/) of your cryptocurrencies.

Following are three major scenarios in which it can be used.

## Scenario: Self-sovereign Account

In a _self-sovereign account_, a user utilizes a multi-sig account to ensure the safety and security of his funds. He does so by creating a 2-of-3 multisignature account where he controls all three of the keys himself, but where he separates them in an intelligent way to ensure their safety.

1. Key #1 is generated as a seed on the phone and left there.
2. Key #2 is generated as a seed on the phone, but after the BIP39 mnemonic phrase is recorded in steel and the multi-sig account is created, the seed is deleted from the phone.
3. Key #3 is generated on a Ledger, Trezor, or other hardware wallet, and its xpub is imported as a cosigner.

The self-sovereign user will usually sign with his hardware wallet (#3) and his Gordian Cosigner app (#1), but if either is lost, he can recover the funds by importing the offline key (#2).

## Scenario: Joint Account

In a _self-sovereign account_, two users utilize a multi-sig account for joint funds, but also maintain a third, offline key in case either of them loses their phone or is incapacitated.

1. Key #1 is generated on the first user's phone and imported into the other's as a cosigner using an xpub.
1. Key #2 is generated on the second user's phone and imported into the other's as a cosigner using an xpub.
1. Key #3 is generated via any means and imported as appropriate. (It might be generated on one of the phones, recorded, and deleted.)

The joint users will usually sign, each using their own Gordian Cosigner, but at any time either one could go to the safe storage for the third key and retrieve it for signing. 

### Scenario Variant: Key Service

In a variant of this scenario, the third key might be held by an online service.

### Scenario Variant: Timelock

In a variant of this scenario, the third key might be protected by a timelock, which would make the funds available to either cosigner when the time has expired.

## Scenario: Traditional 2-of-3

In a traditional 2-of-3 multi-sig account, three people all hold keys for the account, and any two of them can sign.

1. Key #1 is generated on the first user's phone and imported to the others using xpubs.
1. Key #2 is generated on the second user's phone and imported to the others using xpubs.
1. Key #3 is generated on the third user's phone and imported to the others using xpubs.
