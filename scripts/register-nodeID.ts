import { ethers } from "hardhat";
import { Staking } from "../types/Staking";

const STAKING_CONTRACT_ADDRESS = process.env.STAKING_CONTRACT_ADDRESS ?? "";
const NODEID = process.env.NODEID ?? "";

async function main() {
  const [account] = await ethers.getSigners();

  console.log(
    `Register NodeID: address=${STAKING_CONTRACT_ADDRESS}, account=${account.address}, key=${NODEID}`
  );
  console.log(`Account balance: ${(await account.getBalance()).toString()}`);

  const stakingContract = (await ethers.getContractAt(
    "Staking",
    STAKING_CONTRACT_ADDRESS,
    account
  )) as Staking;

  const tx = await stakingContract.registerNodeID(NODEID);
  const receipt = await tx.wait();

  console.log("Registered", tx.hash, receipt);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
