import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer, secondSigner, thirdSigner } = await getNamedAccounts();

    await deploy(CONTRACTS.multisig, {
        from: deployer,
        args: [secondSigner, thirdSigner],
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

func.tags = [CONTRACTS.multisig, "migration", "production"];

export default func;