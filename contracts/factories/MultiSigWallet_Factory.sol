pragma solidity ^0.5.13;

import '../modules/Factory.sol';
import './MultiSigWallet.sol';

contract ERC20_Factory is Factory {
    constructor(address instanceRegistry, address templateContract) public {
        MultiSigWallet template;

        // set instance type
        bytes4 instanceType = bytes4(keccak256(bytes('Wallet')));
        // set initSelector
        bytes4 initSelector = template.initialize.selector;
        // initialize factory params
        Factory._initialize(
            instanceRegistry,
            templateContract,
            instanceType,
            initSelector
        );
    }
}
