const etherlime = require('etherlime-lib')
const ethers = require('ethers')
const {
  hexlify,
  createIPFShash,
  abiEncodeWithSelector,
} = require('../test/helpers/utils')
const { RATIO_TYPES, TOKEN_TYPES } = require('../test/helpers/variables')
const assert = require('assert')

let { c } = require('./deploy_config')

require('dotenv').config()

const deploy = async (network, secret) => {
  console.log(``)
  console.log(`Initialize Deployer`)
  console.log(``)

  let defaultGas = ethers.utils.parseUnits('15', 'gwei')
  let deployer = await new etherlime.InfuraPrivateKeyDeployer(
    process.env.DEPLOYMENT_PRIV_KEY,
    network,
    process.env.INFURA_API_KEY,
    { gasPrice: defaultGas, etherscanApiKey: process.env.ETHERSCAN_API_KEY },
  )

  console.log(`Deployment Wallet: ${deployer.signer.address}`)

  // deploy template

  const multisig_template_artifact = require('../build/MultiSigWallet.json')
  const multisig_template = await deployer.deployAndVerify(
    multisig_template_artifact,
  )

  // deploy factory

  const multisig_factory_artifact = require('../build/MultiSigWallet_Factory.json')
  const multisig_factory = await deployer.deployAndVerify(
    multisig_factory_artifact,
    false,
    ethers.constants.AddressZero,
    multisig_template.contractAddress,
  )

  console.log('multisig_template', multisig_template.contractAddress)
  console.log('multisig_factory', multisig_factory.contractAddress)
}

module.exports = { deploy }
