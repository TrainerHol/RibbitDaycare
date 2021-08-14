import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import { parseEther } from "@ethersproject/units";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();
  await deploy("RibbitDaycare", {
    from: deployer,
    args: ["0xEa319e87Cf06203DAe107Dd8E5672175e3Ee976c", "0xa8e7366031d493A0dF88A583196d092f80152029", "0xaAF49D386bd44E31fF22EDF723F40EE3e4dA53cd", "1000000000000000000"],
    log: true,
  });
};

export default func;
func.id = "deploy_ribbitdaycare";
func.tags = ["RibbitDaycare"];
