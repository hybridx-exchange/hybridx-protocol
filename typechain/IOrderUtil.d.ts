/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import {
  ethers,
  EventFilter,
  Signer,
  BigNumber,
  BigNumberish,
  PopulatedTransaction,
} from "ethers";
import {
  Contract,
  ContractTransaction,
  Overrides,
  CallOverrides,
} from "@ethersproject/contracts";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";

interface IOrderUtilInterface extends ethers.utils.Interface {
  functions: {
    "getAmountInForMovePrice(address,uint256)": FunctionFragment;
    "getAmountOutForMovePrice(address,uint256)": FunctionFragment;
    "initialize(address)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "getAmountInForMovePrice",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getAmountOutForMovePrice",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(functionFragment: "initialize", values: [string]): string;

  decodeFunctionResult(
    functionFragment: "getAmountInForMovePrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getAmountOutForMovePrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "initialize", data: BytesLike): Result;

  events: {};
}

export class IOrderUtil extends Contract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  on(event: EventFilter | string, listener: Listener): this;
  once(event: EventFilter | string, listener: Listener): this;
  addListener(eventName: EventFilter | string, listener: Listener): this;
  removeAllListeners(eventName: EventFilter | string): this;
  removeListener(eventName: any, listener: Listener): this;

  interface: IOrderUtilInterface;

  functions: {
    getAmountInForMovePrice(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountIn: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    "getAmountInForMovePrice(address,uint256)"(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountIn: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    getAmountOutForMovePrice(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountOut: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    "getAmountOutForMovePrice(address,uint256)"(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountOut: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    initialize(
      _orderBook: string,
      overrides?: Overrides
    ): Promise<ContractTransaction>;

    "initialize(address)"(
      _orderBook: string,
      overrides?: Overrides
    ): Promise<ContractTransaction>;
  };

  getAmountInForMovePrice(
    tokenOut: string,
    amountOutOffer: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    amountIn: BigNumber;
    extra: BigNumber[];
    0: BigNumber;
    1: BigNumber[];
  }>;

  "getAmountInForMovePrice(address,uint256)"(
    tokenOut: string,
    amountOutOffer: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    amountIn: BigNumber;
    extra: BigNumber[];
    0: BigNumber;
    1: BigNumber[];
  }>;

  getAmountOutForMovePrice(
    tokenIn: string,
    amountInOffer: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    amountOut: BigNumber;
    extra: BigNumber[];
    0: BigNumber;
    1: BigNumber[];
  }>;

  "getAmountOutForMovePrice(address,uint256)"(
    tokenIn: string,
    amountInOffer: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    amountOut: BigNumber;
    extra: BigNumber[];
    0: BigNumber;
    1: BigNumber[];
  }>;

  initialize(
    _orderBook: string,
    overrides?: Overrides
  ): Promise<ContractTransaction>;

  "initialize(address)"(
    _orderBook: string,
    overrides?: Overrides
  ): Promise<ContractTransaction>;

  callStatic: {
    getAmountInForMovePrice(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountIn: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    "getAmountInForMovePrice(address,uint256)"(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountIn: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    getAmountOutForMovePrice(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountOut: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    "getAmountOutForMovePrice(address,uint256)"(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      amountOut: BigNumber;
      extra: BigNumber[];
      0: BigNumber;
      1: BigNumber[];
    }>;

    initialize(_orderBook: string, overrides?: CallOverrides): Promise<void>;

    "initialize(address)"(
      _orderBook: string,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {};

  estimateGas: {
    getAmountInForMovePrice(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "getAmountInForMovePrice(address,uint256)"(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getAmountOutForMovePrice(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "getAmountOutForMovePrice(address,uint256)"(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    initialize(_orderBook: string, overrides?: Overrides): Promise<BigNumber>;

    "initialize(address)"(
      _orderBook: string,
      overrides?: Overrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    getAmountInForMovePrice(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "getAmountInForMovePrice(address,uint256)"(
      tokenOut: string,
      amountOutOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getAmountOutForMovePrice(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "getAmountOutForMovePrice(address,uint256)"(
      tokenIn: string,
      amountInOffer: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    initialize(
      _orderBook: string,
      overrides?: Overrides
    ): Promise<PopulatedTransaction>;

    "initialize(address)"(
      _orderBook: string,
      overrides?: Overrides
    ): Promise<PopulatedTransaction>;
  };
}