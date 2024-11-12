require("@nomicfoundation/hardhat-verify");

module.exports = {
  solidity: "0.8.7",
  networks: {
    merlin: {
      name: "merlin",
      chainId: 4200,
      url: "https://rpc.merlinchain.io",
      explorer: "https://scan.merlinchain.io/",
    },
    bscTest: {
      name: "bscTest",
      chainId: 97,
      url: "https://bsc-testnet.publicnode.com",
      explorer: "https://testnet.bscscan.com/",
    },
  },
  etherscan: {
    apiKey: {
      merlin: "49b66e7d-ba04-451f-81ad-b66cf4f4ac4c",
      bscTest: "M3741KHTX63J2DACJMKES8NDJ7FAUIEI2J",
    },
    customChains: [
      {
        network: "merlin",
        chainId: 4200,
        urls: {
          apiURL: "https://scan.merlinchain.io/api",
          browserURL: "https://scan.merlinchain.io",
        },
      },
      {
        network: "bscTest",
        chainId: 97,
        urls: {
          apiURL: "https://api-testnet.bscscan.com/api",
          browserURL: "https://testnet.bscscan.com/",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};
