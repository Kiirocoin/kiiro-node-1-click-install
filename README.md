<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]


<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/Kiirocoin/kiiro-node-1-click-install">
    <img src="https://avatars.githubusercontent.com/u/138875999?s=48&v=4" alt="Logo" width="80" height="80">
  </a>
  <h3 align="center">KIIROCOIN 1 CLICK MASTERNODE INSTALL</h3>
</div>


<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://example.com)

Kiirocoin is a privacy focused cryptocurrency that utilizes zero-knowledge proofs which allows users to destroy coins and then redeem them later for brand new ones with no transaction history.

Kiirocoin also utilises Dandelion++ to obscure the originating IP of transactions without relying on any external services such as Tor/i2P.

Kiirocoin uses KiiroPoW (a ProgPoW variant) as its Proof-of-Work GPU focused algorithm which is FPGA/ASIC resistant.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

If you already completed installation and meet minimum requirements then use the following command to install one click installer:
<code>git clone https://github.com/Kiirocoin/kiiro-node-1-click-install.git && sudo bash install.sh</code>

<p>Whether you are hosting with a masternode provider or doing it on your own, ensure you have the latest <a href="https://github.com/Kiirocoin/kiiro/tree/main/" target="_blank">Kiiro wallet</a> and you have already obtained your <strong>1000 KIIRO</strong> (preferably just a bit more to cover fees when you’re transferring around). <strong>Steps 1 and 2 are still required</strong> even if you are going for a masternode provider.</p>
<h3 id="step-1-encrypt-and-backup-your-wallet-on-your-desktop-wallet">Step 1: Encrypt and Backup your wallet on your Desktop wallet</h3>
<p>If you haven’t done so already, make sure you encrypt your wallet on your <strong>local desktop wallet</strong> (PC/Mac/Linux).</p>
<p>Go to <strong>Settings &gt; Encrypt Wallet.</strong></p>
<p>After you have encrypted your wallet, it is also recommended to do a backup via <strong>File &gt; Backup Wallet</strong>. It is recommended to store this wallet on a separate physical drive or pen drive. The wallet.dat is encrypted so even if the wallet.dat is exposed, if your password is long enough, it will be secure.</p>
<p><strong>Please don’t forget your password! No one can help you if you lose your password.</strong></p>
<h3 id="step-2-collateral-your-1000-kiiro-on-your-desktop-wallet">Step 2: collateral your 1000 KIIRO on your Desktop wallet</h3>
<p>Your collateral address is where you will be storing your 1000 KIIRO.</p>
<p>You can create the collateral address in two ways: using the Receive tab, OR in the Debug Window</p>
<h4 id="receive-tab">Receive tab:</h4>
<p>Click on the Receive tab. Enter a label for your collateral address in the Label field and click on Request Payment. A window should pop up with a Kiiro address.</p>
<h4 id="debug-window">Debug Window:</h4>
<p>Go to Help &gt; Debug Window &gt; Console and type in</p>
<p><code class="language-plaintext highlighter-rouge">getnewaddress</code></p>
<p>In one single transaction, send <strong>exactly 1000 KIIRO</strong> into the masternode collateral address that you created. Do not send 500 and then another 500. <strong>It has to be in one single transaction. Do not tick subtract fee from amount.</strong></p>
<p>It is not recommended to send it direct from an exchange as they might deduct certain withdrawal fees resulting in less than 1000 KIIRO in that transfer.</p>
<p>Wait <strong>1 confirmation</strong> for this transaction to be valid as your masternode collateral. When done correctly, the transaction id and transaction index will appear when you execute this command in the Debug Console:</p>
<p><code class="language-plaintext highlighter-rouge">evoznode outputs</code></p>
<h4 id="special-notes-only-for-those-who-are-creating-more-than-one-masternode">Special Notes only for those who are creating more than one masternode:</h4>
<p>If you are doing more than one masternode, special care is required to ensure that you are creating collaterals properly. You do not want to break the previous 1000 KIIRO collateral you just made by taking funds from that collateral.</p>
<p>To do this, on your <strong>local desktop wallet</strong> turn on coin control by going to <strong>Settings &gt; Options &gt; Wallet</strong> and click on <strong>Enable coin control features.</strong> This will enable control of which funds you are using when making your next 1000 KIIRO collateral.</p>
<p>Then go to your Send tab, and you will see <strong>Coin Control Features</strong>. Click on <strong>Inputs</strong>. You should see your 1000 KIIRO collateral there. Right click and click <strong>Lock Unspent</strong>. This means that when making your new collateral, your wallet will not touch these funds.</p>
<p>Once you have done this, you can make the next 1000 KIIRO collateral for your next masternode. Repeat this everytime you have made a new masternode.</p>
<p>You can always verify you’re doing this correctly by going into <strong>Help &gt; Debug Window</strong> and typing <strong>evoznode outputs</strong> which would display all masternode capable collaterals.</p>
<h3 id="step-3-creating-owneraddress-payoutaddress-feesourceaddress-and-operatorkeyoperatorpubkey">Step 3: Creating ownerAddress, payoutAddress, feeSourceAddress and operatorKey/operatorPubKey</h3>
<p><em>a, b, and c can be generated through Receive tab or the Debug Window, just like the collateral address above.</em></p>
<h4 id="a-owneraddress">a. ownerAddress</h4>
<p>Proof that you own the masternode. Must be in the same wallet as collateral. <strong>DO NOT USE THE COLLATERAL ADDRESS AS OWNER ADDRESS.</strong></p>
<p><strong>DO NOT SEND COINS TO THE OWNER ADDRESS. DO NOT USE IT AS PAYOUT ADDRESS. DO NOT USE THIS ADDRESS FOR ANY OTHER PURPOSE.</strong></p>
<h4 id="b-payoutaddress">b. payoutAddress</h4>
<p>Address the masternode will pay out to. Can be inside the same wallet or an external address.</p>
<h4 id="c-feesourceaddress">c. feeSourceAddress</h4>
<p>An address with funds to pay the transaction fee for registering your masternode. To get a list of addresses with funds, enter the following command in the Debug Window:</p>
<p><code class="language-plaintext highlighter-rouge">listaddressbalances 0.01</code></p>
<p>If you do not have any, you can create an address and send some Kiiros there. You can then use the address as feeSourceAddress.</p>
<h4 id="d-operatorkeyoperatorpubkey">d. operatorKey/operatorPubKey</h4>
<p>In Debug Console, enter bls generate. The output will be similar to this:</p>
<div class="language-plaintext highlighter-rouge"><div class="highlight"><pre class="highlight"><code>{
    "secret": "2e551176c4cd5a2e26f3a1c61f151487e013f7095ffbc0f62b5c2b251e7bd84c",
    "public": "89d395bc75e99527e80d3bbd408a5b41bbf37e7e1e26c5924da734008d1aa4a3f5e42a968bef541cb1c9a0899280d29b"
}
</code></pre></div></div>
<p><strong>secret</strong>: This is your operatorKey (for protx) and also the znodeblsprivkey for use in Step 6.</p>
<p><strong>public</strong>: This is your operatorPubKey (for protx)</p>
<p>You cannot <strong>regenerate the same pair of keys,</strong> but you can generate the public key from the secret key if you lose the public key.</p>
<h3 id="step-4-get-a-vps">Step 4: Get a VPS</h3>
<p>There are many providers to choose out there.</p>
<p> <a href="https://hetzner.cloud/?ref=mPIIBRuHJtB4" target="_blank">Hetzner "start from 4.2 euro"</a></p>
<p>  <a href="https://www.vpsag.com/?aff=36435" target="_blank">Vpsag "start from 3.66euro"</a></b>
<p>Select a VPS package that meets the minimum requirements:</p>
<ul>
  <li>1.5 GB of RAM (2 GB with swap on recommended)</li>
  <li>25 GB of disk space </li>
</ul>
<p><strong>Note:</strong> With KiiroPoW, the blockchain grows at a rate of about 1 GB per year. Please make sure you pick a VPS with sufficient disk space.</p>
<p>When choosing a server, please remember reliability is more important than price. If your masternode goes offline, you will potentially miss out on payouts which would be more than your VPS cost.</p>
<p>Pick <strong>Ubuntu 20.04 64-bit</strong> and install it.</p>
<p>Once it is done, the VPS provider should give you a username (usually root) and a password. Use a SSH client like <a href="https://www.putty.org/">Putty</a> or if the VPS provider provides, it open up a console window.</p>
<p align="right">(<a href="#readme-top">back to top</a>)</p>
<!-- USAGE EXAMPLES -->
## Usage

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.md` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Project Link: [https://github.com/Kiirocoin](https://github.com/Kiirocoin)

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/othneildrew/Best-README-Template.svg?style=for-the-badge
[contributors-url]: https://github.com/othneildrew/Best-README-Template/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/othneildrew/Best-README-Template.svg?style=for-the-badge
[forks-url]: https://github.com/othneildrew/Best-README-Template/network/members
[stars-shield]: https://img.shields.io/github/stars/othneildrew/Best-README-Template.svg?style=for-the-badge
[stars-url]: https://github.com/othneildrew/Best-README-Template/stargazers
[issues-shield]: https://img.shields.io/github/issues/othneildrew/Best-README-Template.svg?style=for-the-badge
[issues-url]: https://github.com/othneildrew/Best-README-Template/issues
[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=for-the-badge
[license-url]: https://github.com/othneildrew/Best-README-Template/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/othneildrew
[product-screenshot]: images/screenshot.png
[Next.js]: https://img.shields.io/badge/next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white
[Next-url]: https://nextjs.org/
[React.js]: https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB
[React-url]: https://reactjs.org/
[Vue.js]: https://img.shields.io/badge/Vue.js-35495E?style=for-the-badge&logo=vuedotjs&logoColor=4FC08D
[Vue-url]: https://vuejs.org/
[Angular.io]: https://img.shields.io/badge/Angular-DD0031?style=for-the-badge&logo=angular&logoColor=white
[Angular-url]: https://angular.io/
[Svelte.dev]: https://img.shields.io/badge/Svelte-4A4A55?style=for-the-badge&logo=svelte&logoColor=FF3E00
[Svelte-url]: https://svelte.dev/
[Laravel.com]: https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white
[Laravel-url]: https://laravel.com
[Bootstrap.com]: https://img.shields.io/badge/Bootstrap-563D7C?style=for-the-badge&logo=bootstrap&logoColor=white
[Bootstrap-url]: https://getbootstrap.com
[JQuery.com]: https://img.shields.io/badge/jQuery-0769AD?style=for-the-badge&logo=jquery&logoColor=white
[JQuery-url]: https://jquery.com 
