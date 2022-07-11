/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import { Contract, ContractFactory, Overrides } from "@ethersproject/contracts";

import type { HybridXRouter } from "../HybridXRouter";

export class HybridXRouter__factory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(_config: string, overrides?: Overrides): Promise<HybridXRouter> {
    return super.deploy(_config, overrides || {}) as Promise<HybridXRouter>;
  }
  getDeployTransaction(
    _config: string,
    overrides?: Overrides
  ): TransactionRequest {
    return super.getDeployTransaction(_config, overrides || {});
  }
  attach(address: string): HybridXRouter {
    return super.attach(address) as HybridXRouter;
  }
  connect(signer: Signer): HybridXRouter__factory {
    return super.connect(signer) as HybridXRouter__factory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): HybridXRouter {
    return new Contract(address, _abi, signerOrProvider) as HybridXRouter;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_config",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    stateMutability: "payable",
    type: "fallback",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "clientAddress",
        type: "address",
      },
      {
        internalType: "bytes4[]",
        name: "functionIds",
        type: "bytes4[]",
      },
    ],
    name: "bindFunctions",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "config",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    name: "functionMap",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    stateMutability: "payable",
    type: "receive",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b5060405161066e38038061066e83398101604081905261002f91610054565b600080546001600160a01b0319166001600160a01b0392909216919091179055610084565b60006020828403121561006657600080fd5b81516001600160a01b038116811461007d57600080fd5b9392505050565b6105db806100936000396000f3fe6080604052600436106100385760003560e01c80632a36fb6b146100eb57806379502c551461010b57806383aa3d1a14610147576100e3565b366100e35760008054906101000a90046001600160a01b03166001600160a01b031663f24286216040518163ffffffff1660e01b815260040160206040518083038186803b15801561008957600080fd5b505afa15801561009d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100c19190610403565b6001600160a01b0316336001600160a01b0316146100e1576100e161054b565b005b6100e161017d565b3480156100f757600080fd5b506100e1610106366004610427565b61018f565b34801561011757600080fd5b5060005461012b906001600160a01b031681565b6040516001600160a01b03909116815260200160405180910390f35b34801561015357600080fd5b5061012b610162366004610507565b6001602052600090815260409020546001600160a01b031681565b61018d610188610348565b6103c7565b565b60008054906101000a90046001600160a01b03166001600160a01b0316638da5cb5b6040518163ffffffff1660e01b815260040160206040518083038186803b1580156101db57600080fd5b505afa1580156101ef573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102139190610403565b6001600160a01b0316336001600160a01b0316146102735760405162461bcd60e51b8152602060048201526018602482015277243cb13934b22c2937baba32b91d102327a92124a22222a760411b60448201526064015b60405180910390fd5b60005b81518110156103435760006001600160a01b0316600160008484815181106102a0576102a0610561565b6020908102919091018101516001600160e01b0319168252810191909152604001600020546001600160a01b0316146102d857600080fd5b82600160008484815181106102ef576102ef610561565b6020908102919091018101516001600160e01b031916825281019190915260400160002080546001600160a01b0319166001600160a01b03929092169190911790558061033b81610522565b915050610276565b505050565b600080356001600160e01b0319168152600160205260408120546001600160a01b0316806103c25760405162461bcd60e51b815260206004820152602160248201527f48796272696458526f757465723a2046756e6374696f6e204e6f7420457869736044820152601d60fa1b606482015260840161026a565b919050565b3660008037600080366000845af43d6000803e8080156103e6573d6000f35b3d6000fd5b80356001600160e01b0319811681146103c257600080fd5b60006020828403121561041557600080fd5b81516104208161058d565b9392505050565b6000806040838503121561043a57600080fd5b82356104458161058d565b91506020838101356001600160401b038082111561046257600080fd5b818601915086601f83011261047657600080fd5b81358181111561048857610488610577565b8060051b604051601f19603f830116810181811085821117156104ad576104ad610577565b604052828152858101935084860182860187018b10156104cc57600080fd5b600095505b838610156104f6576104e2816103eb565b8552600195909501949386019386016104d1565b508096505050505050509250929050565b60006020828403121561051957600080fd5b610420826103eb565b600060001982141561054457634e487b7160e01b600052601160045260246000fd5b5060010190565b634e487b7160e01b600052600160045260246000fd5b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052604160045260246000fd5b6001600160a01b03811681146105a257600080fd5b5056fea26469706673582212204371a5d12f181ee87dfe8c1d6bea51354aec1af1b949b35e299f9ef8e6273ede64736f6c63430008050033";