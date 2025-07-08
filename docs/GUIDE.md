# Qubic Development Kit & Testnet Guide

Welcome to the Qubic Dev Kit, your all-in-one solution for creating and testing smart contracts on the Qubic network. This guide is designed for developers, especially those participating in events like **Hackathon Madrid 2025**.

This project provides a fully automated script (`testnet_setup.sh`) that builds a complete, local Qubic development environment from scratch.

---

## 🚀 Getting Started: The One-Command Setup

vsion: The entire environment, from system dependencies to a running testnet node, is handled by a single script.
current:<br />,br />
To begin, run the setup script from your terminal:

```bash
sudo ./environment_setup.sh
```

> **Note:** If you have already run the script successfully, you can skip to the next section.


This script will:<br /><br />
✅ Install all required software (VirtualBox, Docker, build tools)<br /><br />
✅ Clone the necessary Qubic source code repositories<br /><br />
✅ Compile the qubic-cli and qlogging tools<br /><br />
✅ Download and prepare the testnet virtual hard disk (VHD)<br /><br />
# almost ..... ✅ Automatically configure and launch your testnet node in VirtualBox<br /><br />
# 🖥️ Using Your Deployed Testnet Environment
Once the script finishes, your testnet node is already running in the background. Here’s how to interact with it<br /><br />
# Monitoring Your Node with qlogging
The most important tool for debugging is qlogging, which shows a real-time feed of transactions and events on your node.
To start monitoring, run the following command from your host machine's terminal:
```bash
/opt/qubic/bin/qlogging
```
You will see output similar to this, which is invaluable for seeing how your smart contracts are behaving:
```txt
EventTx #1FromId Told1 2 21183461.153 QU transfer: from WTUBWAEQJHTFIEDXCJHVRXAXYBFCHAPQUPOQMGTJVGXYEBVRYTOVFHLFBCMB to MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWWD 10000QU.
Tick 21183462 doesn't generate any log
 21183473.153 Burn: MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWLWD burned 100000 QU
```
# Managing the Virtual Machine
Your node runs inside a VirtualBox VM named "Qubic Testnet Node". You can manage it from the command line:
To Stop the Node (Graceful Shutdown):
```bash
VBoxManage controlvm "Qubic Testnet Node" acpipowerbutton
To Force a Shutdown (Power Off):
VBoxManage controlvm "Qubic Testnet Node" poweroff
To Start the Node Again Later:
VBoxManage startvm "Qubic Testnet Node" --type headless
```
💰 Testnet Resources
Getting Testnet Funds (Faucet)
You need test funds to deploy and interact with smart contracts.
Join the official Qubic Discord.
Navigate to the #bot-commands channel.
Use the /faucet command to receive test Qubics for the testnet.
Pre-Funded Testnet Seeds
For quick testing, the following seeds are available on the testnet, each containing approximately 1 billion testnet Qubic tokens.
<details>
<summary>🔑 **Click to view 27 available pre-funded seeds**</summary>
Generated code
fwqatwliqyszxivzgtyyfllymopjimkyoreolgyflsnfpcytkhagqii
xpsxzzfqvaohzzwlbofvqkqeemzhnrscpeeokoumekfodtgzmwghtqm
ukzbkszgzpipmxrrqcxcppumxoxzerrvbjgthinzodrlyblkedutmsy
wgfqazfmgucrluchpuivdkguaijrowcnuclfsjrthfezqapnjelkgll
kewgvatawujuzikurbhwkrisjiubfxgfqkrvcqvfvgfgajphbvhlaos
nkhvicelolicthrcupurhzyftctcextifzkoyvcwgxnjsjdsfrtbrbl
otyqpudtgogpornpqbjfzkohralgffaajabxzhneoormvnstheuoyay
ttcrkhjulvxroglycvlpgesnxpwgjgvafpezwdezworzwcfobevoacx
mvssxxbnmincnnjhtrlbdffulimsbmzluzrtbjqcbvaqkeesjzevllk
jjhikmkgwhyflqdszdxpcjrilnoxerfeyttbbjahapatglpqgctnkue
nztizdwotovhuzchctpfdgylzmsdfxlvdcpikhmptqjbwwgbxavhtwo
lxbjeczdoqyjtzhizbeapkbpvfdbgxxbdbhyfvzhbkysmgdxuzspmwu
zwoggmzfbdhuxrikdhqrmcxaqmpmdblgsdjzlesfnyogxquwzutracm
inkzmjoxytbhmvuuailtfarjgooearejunwlzsnvczcamsvjlrobsof
htvhtfjxzqandmcshkfifmrsrikrcpsxmnemcjthtmyvsqqcvwckwfk
hmsmhamftvncxcdvxytqgdihxfncarwzatpjuoecjqhceoepysozwlp
wrnohgpgfuudvhtwnuyleimplivlxcaswuwqezusyjddgkdigtueswb
fisfusaykkovsskpgvsaclcjjyfstrstgpebxvsqeikhneqaxvqcwsf
jftgpcowwnmommeplhbvgotjxrtkmiddcjmitbxoekwunmlpmdakjzq
svaluwylhjejvyjvgmqsqjcufulhusbkkujwrwfgdphdmesqjirsoep
lzinqhyvomjzqoyluifguhytcgpftdxndswbcqriecatcmfidbnmvka
mqamjotnshocvekufdqylgtdcembtddlfockjyaotfdvzqpvkylsjjk
asueorfnexvnthcuicsqqppekcdrwizxqlnkzdkazsymrotjtmdnofe
ahfulnoaeuoiurixbjygqxiaklmiwhysazqylyhhitjsgezhqwnpgql
omyxajeenkikjvihmysvkbftzqrtsjfstlmycfwqjyaihtldnetvkrw
zrfpagcpqfkwjimnrehibkctvwsyzocuikgpedchcyaotcamzaxpivq
kexrupgtmbmwwzlcpqccemtgvolpzqezybmgaedaganynsnjijfyvcn```
</details>

### Using the Qubic CLI
You can use the compiled `qubic-cli` tool with a pre-funded seed to interact with your node. Since your node is running locally, the IP is `127.0.0.1` and the port is typically `21841`.

**Example:**
```bash
/opt/qubic/bin/qubic-cli -nodeip 127.0.0.1 -nodeport 21841 -seed fwqatwliqyszxivzgtyyfllymopjimkyoreolgyflsnfpcytkhagqii -somecommand
```
🔬 Advanced: Querying a Smart Contract
Here is a quick guide on how to read data from a smart contract using the RPC API.
Step 1: Identify the Smart Contract Function
In your contract's C++ code, find the function you want to call. For this example, we'll use the Fees function from the QX contract.
```c++
struct QX : public ContractBase {
public:
    struct Fees_input {};
    struct Fees_output {
        uint32 assetIssuanceFee; // Amount of qus
        uint32 transferFee;      // Amount of qus
        uint32 tradeFee;         // Number of billionths
    };
    // ...
};
```
# Find the Function Registration
Look for the REGISTER_USER_FUNCTION macro in the code. This gives you the function number.
```c++
REGISTER_USER_FUNCTION(Fees, 1) // The function number is 1
# Determine the Contract Index
Find the #define for the contract index.
```c++
#define CONTRACT_INDEX_QX 1 // The contract index is 1
```
# Construct the API Request
Use curl to send a request to a public RPC node.
```bash
curl -X 'POST' \
  'https://rpc.qubic.org/v1/querySmartContract' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "contractIndex": 1,
  "inputType": 1,
  "inputSize": 0,
  "requestData": ""
}'
```
This should return a response like: {"responseData":"AMqaO0BCDwBAS0wA"}<br /><br />
💡 Best Practices<br /><br />
Use the CLI for Initial Testing: It's the most direct way to interact with your contracts<br /><br />
Monitor Logs: Always have a terminal open running qlogging to see what's happening<br /><br />
Test with Small Amounts: Even with testnet funds, it's good practice<br /><br />
Document Your Contract Index: Keep track of your contract's index for future reference<br /><br />
# 💬 Support & Resources
Qubic Main Org: https://github.com/qubic<br /><br />
Documentation: https://github.com/qubic/docs<br /><br />
Get Help: For questions or if you need server resources, join the Qubic Discord and ask in the #dev channel<br /><br />
