# Blockchain Commons GordianCosigner-Catalyst
### _by [Peter Denton](https://github.com/Fonta1n3) and [Christopher Allen](https://github.com/ChristopherA)_
* <img src="https://github.com/BlockchainCommons/Gordian/blob/master/Images/logos/gordian-icon.png" width=16 valign="bottom"> ***part of the [gordian](https://github.com/BlockchainCommons/gordian/blob/master/README.md) technology family***

![](images/logos/gordian-cosigner-screen.jpg)

**Gordian Cosigner** allows users to participate in a multisig by adding a signature to an otherwise unsigned or partially signed PSBT that was created on another device. It's largely intended as an offline signing tool, which allows signing without a direct connection to a full node: a wallet that can create PSBTs or another transaction coordinator service is needed to initiate a transaction.

(Gordian Cosigner can also be used for signing a single-signature PSBT, though that's not its main purpose.)

## Additional Information

### Documents

* [Integration](Docs/Integrating.md) — Using **Gordian Cosigner** with other applications.
* [User Scenarios](Docs/Scenarios.md) — Reasons that you might use multisignatures to ensure the [#SmartCustody](https://www.smartcustody.com/) of your funds.

### Other Gordian Applications

This is a companion app for the Gordian system:

* [Gordian system](https://github.com/BlockchainCommons/Gordian) — A self-sovereign Bitcoin wallet and node

Gordian Cosigner is a multiplatform utility that's also available as:

* [GordianCosigner for Android](https://github.com/BlockchainCommons/GordianSigner-Android)
* [GordianCosigner for MacOS](https://github.com/BlockchainCommons/GordianSigner-macOS)

Some of Cosigner's functioanlity has been superceded by the newer Gordian SeedTool app:

* [Gordian SeedTool](https://github.com/BlockchainCommons/GordianSeedTool-iOS) — An app for storing seeds and for signing PSBTs with those seeds

However, they both remain useful reference apps for demonstrating the use of Gordian Principles and Blockchain Commons specifications.

## Gordian Principles

**Gordian Cosigner** is a reference implementation meant to display the [Gordian Principles](https://github.com/BlockchainCommons/Gordian#gordian-principles), which are philosophical and technical underpinnings to Blockchain Commons' Gordian technology. This includes:

* **Independence.** Cosigner allows you to sign PSBTs in a way you see fit.
* **Privacy.** Cosigner keeps your signing totally offline.
* **Resilience.** Cosigner also keeps your seeds offline, just communicating signatures through airgaps.
* **Openness.** Cosigner communicates through airgaps via URs and QRs, for maximum interoperability.

Blockchain Commons apps do not phone home and do not run ads. Some are available through various app stores; all are available in our code repositories for your usage.

## Status - Late Alpha

GordianCosigner-Catalyst is currently a late alpha. It should not be used for production tasks until it has had further testing and auditing. Though it now supports mainnet interactions, it should be considered _very risky_ to use, and minimal Bitcoin funds should be used for testing.

At current, this Catalyst repo is only used for our iOS release, but we hope to eventually use it for the MacOS release as well. (A security lock on the MacOS camera currently prevents us from doing so.)

## Installation Instructions

**Gordian Cosigner** is available for testing from Testflight [here](https://testflight.apple.com/join/sJTaoUsM).

## Usage Instructions

**Gordian Cosigner** supports the middle step of multisig signing, after a multisig has been Initiated, while it is being Cosigned, and before it is Finalized. Usually, it will be used by a cosigner holding one of the keys used in a multisig account transaction before handing it back to another user for finalization.

### Preparing for Usage

To prepare **Gordian Cosigner** for usage, you must first create a copy of the multisig that is being used. This is done by defining an account containing all of the cosigners in the multisig. The user of **Gordian Cosigner** will typically have a private key or seed for his own cosigner element, and then will typically be given an account map for the multisig and/or xpubs or QR codes for other users' cosigner elements. When he imports the account map or combines the cosigners into an account, it should match the multisig created by other people on their own wallets. (See our [Scenarios page](Docs/Scenarios.md) for more discussion of how **Gordian Cosigner** might be used.)

To prepare an account for usage:

1. **Gather Cosigners.** Import all cosigners who will be involved in the multisig account in the **Cosigners** tab.
   * To import a cosigner, select "Import" and paste in origin info, `crypto-account`, `crypto-hdkey`, `crypto-seed`, or BIP39 words, or else scan a QR code.
      * _You will typically import public-key information for other signers, and you may import private-key information for your own signatures._
   * There is currently a "Create Cosigner" function available mainly for testing that allows you to create seeds on the device itself. To create a cosigner, select "Create". Afterward, be sure to record offline backups of your cosigner's QR codes and text, especially the seed info (if any).
2. **Form Account.** Import an account from the **Accounts** tab. 
   * To import an account, select "Import" and scan an "Account Map" (wallet backup QR) from Gordian Wallet, Fully Noded, or Specter. 
   * There is currently a "Create Cosigner" function available mainly for testing that allows you to create new maps on the device itself. To create an account, select "Create", set a policy and then select which cosigners you would like to add to the account. Once a sufficient number of cosigners have been added to the account, it will automatically complete.
3. **Check Address.** Tap the detail button, then the **address explorer** button on the **Accounts** tab to see each address for the account; cross-check the first several "Receive" addresses with your other wallet software to ensure they match.

### Signing Multisigs

To use **Gordian Cosigner** for cosigning for multisig addresses, you must import a PSBT, sign, and then export it.

1. **Create PSBT.** Create a PSBT with a network connected wallet using the same **account** and pass that PSBT to Gordian Cosigner in the **Payments** tab.
2. **Sign PSBT.** Sign the psbt (ensuring you have added the necessary cosigner).
3. **Export PSBT.** Either export the incomplete PSBT to another signer or else the export finalized hex raw transaction to a networked wallet for broadcasting.

Be sure to see the article on [Integrating Gordian Cosigner](Docs/Integrating.md) for some complete examples of how other systems can be used to build up the initial and final parts of the multisigning process.

### Backup & Recovery

**Gordian Cosigner** will automatically backup all data if your device is logged in to iCloud. If keychain "iCloud sync" is enabled you may easily recover all data across different devices which are signed in to the same iCloud account. If you do not have keychain sync enabled then you will only be able to automatically recover from the same device.

## Origin, Authors, Copyright & Licenses

Unless otherwise noted (either in this [/README.md](./README.md) or in the file's header comments) the contents of this repository are Copyright © 2020 by Blockchain Commons, LLC, and are [licensed](./LICENSE) under the [spdx:BSD-2-Clause Plus Patent License](https://spdx.org/licenses/BSD-2-Clause-Patent.html).

In most cases, the authors, copyright, and license for each file reside in header comments in the source code. When it does not, we have attempted to attribute it accurately in the table below.

This table below also establishes provenance (repository of origin, permalink, and commit id) for files included from repositories that are outside of this repo. Contributors to these files are listed in the commit history for each repository, first with changes found in the commit history of this repo, then in changes in the commit history of their repo of their origin.

| File      | From                                                         | Commit                                                       | Authors & Copyright (c)                                | License                                                     |
| --------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------------- |
| exception-to-the-rule.c or exception-folder | [https://github.com/community/repo-name/PERMALINK](https://github.com/community/repo-name/PERMALINK) | [https://github.com/community/repo-name/commit/COMMITHASH]() | 2020 Exception Author  | [MIT](https://spdx.org/licenses/MIT)                        |

### Dependencies

To build GordianCosigner-Catalyst you'll need to use the following tools:

- Xcode - ([Xcode](https://apps.apple.com/id/app/xcode/id497799835?mt=12)).
- macOS 10.15 or iOS 13

### Derived from…

This GordianCosigner-Catalyst project is either derived from or was inspired by:

- [BlockchainCommons/GordianWallet-iOS](https://github.com/BlockchainCommons/GordianWallet-iOS) — Bitcoin wallet powered by your own node over Tor, from [BlockchainCommons](https://github.com/BlockchainCommons).

### Used with…

These are other projects that work with or leverage GordianCosigner-Catalyst:

- [BlockchainCommons/bc-libwally-core](https://github.com/BlockchainCommons/bc-libwally-core) — Used for signing PSBT's offline, from [ElementsProject](https://github.com/ElementsProject).

- [BlockchainCommons/bc-libwally-swift](https://github.com/BlockchainCommons/bc-libwally-swift) — A swift wrapper built around Libwally-core, from [blockchain](https://github.com/blockchain).

## Financial Support

GordianCosigner-Catalyst is a project of [Blockchain Commons](https://www.blockchaincommons.com/). We are proudly a "not-for-profit" social benefit corporation committed to open source & open development. Our work is funded entirely by donations and collaborative partnerships with people like you. Every contribution will be spent on building open tools, technologies, and techniques that sustain and advance blockchain and internet security infrastructure and promote an open web.

To financially support further development of GordianCosigner-Catalyst and other projects, please consider becoming a Patron of Blockchain Commons through ongoing monthly patronage as a [GitHub Sponsor](https://github.com/sponsors/BlockchainCommons). You can also support Blockchain Commons with bitcoins at our [BTCPay Server](https://btcpay.blockchaincommons.com/).

## Contributing

We encourage public contributions through issues and pull requests! Please review [CONTRIBUTING.md](./CONTRIBUTING.md) for details on our development process. All contributions to this repository require a GPG signed [Contributor License Agreement](./CLA.md).

### Discussions

The best place to talk about Blockchain Commons and its projects is in our GitHub Discussions areas.

[**Gordian System Discussions**](https://github.com/BlockchainCommons/Gordian/discussions). For users and developers of the Gordian system, including the Gordian Server, Bitcoin Standup technology, QuickConnect, and the Gordian Wallet. If you want to talk about our linked full-node and wallet technology, suggest new additions to our Bitcoin Standup standards, or discuss the implementation our standalone wallet, the Discussions area of the [main Gordian repo](https://github.com/BlockchainCommons/Gordian) is the place.

[**Wallet Standard Discussions**](https://github.com/BlockchainCommons/AirgappedSigning/discussions). For standards and open-source developers who want to talk about wallet standards, please use the Discussions area of the [Airgapped Signing repo](https://github.com/BlockchainCommons/AirgappedSigning). This is where you can talk about projects like our [LetheKit](https://github.com/BlockchainCommons/bc-lethekit) and command line tools such as [seedtool](https://github.com/BlockchainCommons/bc-seedtool-cli), both of which are intended to testbed wallet technologies, plus the libraries that we've built to support your own deployment of wallet technology such as [bc-bip39](https://github.com/BlockchainCommons/bc-bip39), [bc-slip39](https://github.com/BlockchainCommons/bc-slip39), [bc-shamir](https://github.com/BlockchainCommons/bc-shamir), [Sharded Secret Key Reconstruction](https://github.com/BlockchainCommons/bc-sskr), [bc-ur](https://github.com/BlockchainCommons/bc-ur), and the [bc-crypto-base](https://github.com/BlockchainCommons/bc-crypto-base). If it's a wallet-focused technology or a more general discussion of wallet standards,discuss it here.

[**Blockchain Commons Discussions**](https://github.com/BlockchainCommons/Community/discussions). For developers, interns, and patrons of Blockchain Commons, please use the discussions area of the [Community repo](https://github.com/BlockchainCommons/Community) to talk about general Blockchain Commons issues, the intern program, or topics other than the [Gordian System](https://github.com/BlockchainCommons/Gordian/discussions) or the [wallet standards](https://github.com/BlockchainCommons/AirgappedSigning/discussions), each of which have their own discussion areas.

### Other Questions & Problems

As an open-source, open-development community, Blockchain Commons does not have the resources to provide direct support of our projects. Please consider the discussions area as a locale where you might get answers to questions. Alternatively, please use this repository's [issues](./issues) feature. Unfortunately, we can not make any promises on response time.

If your company requires support to use our projects, please feel free to contact us directly about options. We may be able to offer you a contract for support from one of our contributors, or we might be able to point you to another entity who can offer the contractual support that you need.

### Credits

The following people directly contributed to this repository. You can add your name here by getting involved. The first step is learning how to contribute from our [CONTRIBUTING.md](./CONTRIBUTING.md) documentation.

| Name              | Role                | Github                                            | Email                                                       | GPG Fingerprint                                    |
| ----------------- | ------------------- | ------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------- |
| Christopher Allen | Principal Architect | [@ChristopherA](https://github.com/ChristopherA) | \<ChristopherA@LifeWithAlacrity.com\>                       | FDFE 14A5 4ECB 30FC 5D22  74EF F8D3 6C91 3574 05ED |
| Peter Denton      | Project Lead        | [@Fonta1n3](https://github.com/Fonta1n3)          | <[FontaineDenton@gmail.com](mailto:FontaineDenton@gmail.com)> | 1C72 2776 3647 A221 6E02  E539 025E 9AD2 D3AC 0FCA  |

## Responsible Disclosure

We want to keep all of our software safe for everyone. If you have discovered a security vulnerability, we appreciate your help in disclosing it to us in a responsible manner. We are unfortunately not able to offer bug bounties at this time.

We do ask that you offer us good faith and use best efforts not to leak information or harm any user, their data, or our developer community. Please give us a reasonable amount of time to fix the issue before you publish it. Do not defraud our users or us in the process of discovery. We promise not to bring legal action against researchers who point out a problem provided they do their best to follow the these guidelines.

### Reporting a Vulnerability

Please report suspected security vulnerabilities in private via email to ChristopherA@BlockchainCommons.com (do not use this email for support). Please do NOT create publicly viewable issues for suspected security vulnerabilities.

The following keys may be used to communicate sensitive information to developers:

| Name              | Fingerprint                                        |
| ----------------- | -------------------------------------------------- |
| Christopher Allen | FDFE 14A5 4ECB 30FC 5D22  74EF F8D3 6C91 3574 05ED |

You can import a key by running the following command with that individual’s fingerprint: `gpg --recv-keys "<fingerprint>"` Ensure that you put quotes around fingerprints that contain spaces.
