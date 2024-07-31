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
  },
  etherscan: {
    apiKey: {
      merlin: "49b66e7d-ba04-451f-81ad-b66cf4f4ac4c",
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
    ],
  },
  sourcify: {
    enabled: false,
  },
};
